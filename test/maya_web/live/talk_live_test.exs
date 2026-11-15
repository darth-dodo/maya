defmodule MayaWeb.TalkLiveTest do
  # Not async: the screen's Conversation runs outside the test process (shared sandbox and stubs).
  use MayaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Maya.Voice.Turn

  setup {Req.Test, :set_req_test_to_shared}

  setup %{conn: conn} do
    :ok = Maya.GameData.import!()

    # The agent answers with the Question, so screen tests read one known text.
    Req.Test.stub(Maya.OpenRouter, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      question = List.last(Jason.decode!(body)["messages"])["content"]
      message = %{"role" => "assistant", "content" => question}
      Req.Test.json(conn, %{"choices" => [%{"message" => message}]})
    end)

    guest = "talk-#{System.unique_integer([:positive])}"
    on_exit(fn -> Maya.Conversation.stop(guest) end)
    %{guest: guest, conn: Plug.Test.init_test_session(conn, guest_id: guest)}
  end

  defp sse(type, extra),
    do: "event: #{type}\ndata: #{Jason.encode!(Map.put(extra, "type", type))}\n\n"

  defp stub(stt, tts) do
    Req.Test.stub(Maya.Mistral, fn
      %{request_path: "/v1/audio/transcriptions"} = conn -> stt.(conn)
      %{request_path: "/v1/audio/speech"} = conn -> tts.(conn)
    end)
  end

  defp text(text), do: &Req.Test.json(&1, %{"text" => text})

  defp speak(conn) do
    body =
      sse("speech.audio.delta", %{"audio_data" => Base.encode64(<<1, 2>>)}) <>
        sse("speech.audio.done", %{})

    Plug.Conn.send_resp(conn, 200, body)
  end

  defp ask(view) do
    view
    |> file_input("#question-form", :question, [
      %{name: "question.wav", content: "RIFFclip", type: "audio/wav"}
    ])
    |> render_upload("question.wav")
  end

  test "the Talk button starts idle and is bound to the Talk hook", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#talk-button[data-state='idle'][phx-hook='TalkHook']")
    assert has_element?(view, "#talk-button[data-sample-rate='24000']")
    refute has_element?(view, "#conversation .turn")
  end

  test "the screen shows the session guest's turns and no other guest's", %{
    conn: conn,
    guest: guest
  } do
    {:ok, _} = Turn.insert(%Turn{guest_id: guest, question: "Mine", answer: "Yours"})
    {:ok, _} = Turn.insert(%Turn{guest_id: "someone-else", question: "Theirs", answer: "No"})

    {:ok, view, _html} = live(conn, ~p"/")

    assert view |> element("#conversation .turn .question") |> render() =~ "Mine"
    refute has_element?(view, "#conversation .turn .question", "Theirs")
  end

  test "a session with no guest reloads the page so the pipeline gives it one" do
    # A fresh conn: the setup conn's test session already holds a guest.
    assert {:error, {:redirect, %{to: "/"}}} =
             live_isolated(build_conn(), MayaWeb.TalkLive, session: %{})
  end

  test "Start fresh asks first, then offers a form that posts to /fresh", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    refute has_element?(view, "#start-fresh-confirm")

    view |> element("#start-fresh-button") |> render_click()
    assert has_element?(view, "#start-fresh-confirm[action='/fresh'][method='post']")
    assert has_element?(view, "#start-fresh-confirm input[name='_csrf_token']")
    assert has_element?(view, "#start-fresh-confirm #start-fresh-yes[type='submit']")

    view |> element("#keep-talking") |> render_click()
    refute has_element?(view, "#start-fresh-confirm")
    assert has_element?(view, "#start-fresh-button")
  end

  test "the upload accepts one clip of at most 1 MB", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "#question-form input[type=file]:not([multiple])")

    big =
      file_input(view, "#question-form", :question, [
        %{name: "question.wav", content: :binary.copy("a", 1_000_001), type: "audio/wav"}
      ])

    assert {:error, [[_ref, :too_large]]} = render_upload(big, "question.wav")
  end

  test "one upload is transcribed, answered, spoken and shown", %{conn: conn, guest: guest} do
    stub(text("Where is Ralts"), &speak/1)
    {:ok, view, _html} = live(conn, ~p"/")

    ask(view)

    assert_push_event(view, "heard", %{})
    assert_push_event(view, "audio", %{pcm: pcm})
    assert Base.decode64!(pcm) == <<1, 2>>
    assert_push_event(view, "audio_done", %{})

    assert view |> element("#conversation .turn .question") |> render() =~ "Where is Ralts"
    assert view |> element("#conversation .turn .answer") |> render() =~ "Where is Ralts"
    refute has_element?(view, "#badge-case")
    # A call returns only after the Conversation stored the turn.
    _ = Maya.Conversation.turns(guest)
    assert [%Turn{question: "Where is Ralts"}] = Turn.recent(guest)
  end

  test "playback timings are stored, junk values are dropped", %{conn: conn, guest: guest} do
    stub(text("Where is Ralts"), &speak/1)
    {:ok, view, _html} = live(conn, ~p"/")
    ask(view)
    assert_push_event(view, "audio_done", %{})
    _ = render(view)

    view
    |> element("#talk-button")
    |> render_hook("playback_started", %{"mic_release_ms" => 180, "playback_start_ms" => "soon"})

    _ = Maya.Conversation.turns(guest)
    assert [%Turn{mic_release_ms: 180, playback_start_ms: nil}] = Turn.recent(guest)
  end

  test "barge-in keeps the Answer as text and marks it cut", %{conn: conn, guest: guest} do
    me = self()

    stub(text("Where is Ralts"), fn conn ->
      send(me, :speaking)
      Process.sleep(:infinity)
      conn
    end)

    {:ok, view, _html} = live(conn, ~p"/")
    ask(view)
    assert_receive :speaking

    view |> element("#talk-button") |> render_hook("barge_in", %{})

    _ = Maya.Conversation.turns(guest)
    assert view |> element("#conversation .turn .cut") |> render() =~ "cut short"
    assert view |> element("#conversation .turn .answer") |> render() =~ "Where is Ralts"
  end

  test "TTS down shows the Answer with a voice is down note", %{conn: conn} do
    stub(text("Where is Ralts"), &Plug.Conn.send_resp(&1, 503, "down"))
    {:ok, view, _html} = live(conn, ~p"/")

    ask(view)

    assert_push_event(view, "voice_down", %{})
    assert view |> element("#conversation .turn .voice-down") |> render() =~ "voice is down"
    assert view |> element("#conversation .turn .answer") |> render() =~ "Where is Ralts"
    refute has_element?(view, "#voice-down")
  end

  test "STT down shows the voice is down note on its own", %{conn: conn} do
    stub(&Plug.Conn.send_resp(&1, 500, "down"), &speak/1)
    {:ok, view, _html} = live(conn, ~p"/")

    ask(view)

    assert_push_event(view, "voice_down", %{})
    assert view |> element("#voice-down") |> render() =~ "voice is down"
    refute has_element?(view, "#conversation .turn")
  end
end
