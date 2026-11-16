defmodule MayaWeb.TalkLiveTest do
  # Not async: the screen's Conversation runs outside the test process (shared sandbox and stubs).
  use MayaWeb.ConnCase, async: false

  import Ecto.Query
  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest

  require Logger

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

  # One hold: a stream start, two 200 ms chunks of silence and the end of the stream.
  defp ask(view) do
    button = element(view, "#talk-button")
    render_hook(button, "stream_start", %{})

    for _ <- 1..2,
        do: render_hook(button, "audio_chunk", %{"audio" => Base.encode64(<<0::51_200>>)})

    render_hook(button, "stream_end", %{})
  end

  defp earn(guest, badges) do
    _ = Maya.GameData.progress(guest)

    query =
      from p in "progress",
        where: p.guest_id == ^guest,
        update: [set: [badges: type(^badges, {:array, :integer})]]

    {1, _} = Maya.Repo.update_all(query, [])
  end

  defp count(html, selector),
    do: html |> LazyHTML.from_fragment() |> LazyHTML.query(selector) |> Enum.count()

  defp texts(html, selector) do
    html
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(selector)
    |> Enum.map(&(&1 |> LazyHTML.text() |> String.trim()))
  end

  test "the trainer card shows the seed Progress", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/talk")

    assert has_element?(view, "#talk-screen #trainer-card #pokeball.pokeball-emerald")
    assert has_element?(view, "#trainer-card #location", "Littleroot Town")
    assert has_element?(view, "#next-gym strong", "Next gym: Roxanne")
    assert has_element?(view, "#next-gym .type-chip.type-rock", "Rock")
    assert has_element?(view, "#team .mon", "Mudkip Lv 5")
    assert view |> element("#team") |> render() |> count(".type-dot.type-water") == 1
    assert has_element?(view, "#badge-count", "0 of 8 badges")
  end

  test "earned badges move the Next gym and fill their slots", %{conn: conn, guest: guest} do
    earn(guest, [1, 2])
    {:ok, view, html} = live(conn, ~p"/talk")

    assert has_element?(view, "#next-gym strong", "Next gym: Wattson")
    assert has_element?(view, "#next-gym .type-chip.type-electric", "Electric")
    assert has_element?(view, "#badge-count", "2 of 8 badges")
    assert html |> count("#badge-case .badge-slot[data-earned='true']") == 2

    for later <- ~w(Flannery Norman Winona Tate Liza Juan),
        do: refute(has_element?(view, "#talk-screen", later), "#{later} on the page")
  end

  test "with all 8 badges the card says so and shows no type chip", %{conn: conn, guest: guest} do
    earn(guest, Enum.to_list(1..8))
    {:ok, view, _html} = live(conn, ~p"/talk")

    assert has_element?(view, "#next-gym", "All 8 badges earned")
    refute has_element?(view, "#next-gym .type-chip")
    assert has_element?(view, "#badge-count", "8 of 8 badges")
  end

  test "the screen root and status follow the Talk button's moments", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/talk")

    assert has_element?(view, "#talk-screen[data-state='idle']")

    assert has_element?(
             view,
             "#talk-status[role='status'][aria-live='polite']",
             "Ready when you are"
           )

    for {state, status} <- [
          {"recording", "Listening to you…"},
          {"uploading", "Thinking…"},
          {"waiting", "Thinking…"},
          {"speaking", "Maya is speaking"},
          {"idle", "Ready when you are"}
        ] do
      view |> element("#talk-button") |> render_hook("talk_state", %{"state" => state})
      assert has_element?(view, "#talk-screen[data-state='#{state}']")
      assert has_element?(view, "#talk-status", status)
      assert has_element?(view, "#talk-status .wave[aria-hidden='true']") == (state == "speaking")
    end
  end

  test "an unknown moment is ignored", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/talk")
    view |> element("#talk-button") |> render_hook("talk_state", %{"state" => "recording"})
    view |> element("#talk-button") |> render_hook("talk_state", %{"state" => "dancing"})

    assert has_element?(view, "#talk-screen[data-state='recording']")
  end

  describe "hold end report" do
    setup do
      level = Logger.level()
      Logger.configure(level: :info)
      on_exit(fn -> Logger.configure(level: level) end)
    end

    test "is logged at info with how and how long, nothing else", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/talk")

      log =
        capture_log([level: :info], fn ->
          view
          |> element("#talk-button")
          |> render_hook("hold_ended", %{
            "ended_by" => "pointercancel",
            "hold_ms" => 840,
            "lost_capture" => true,
            "mic_open_ms" => 120,
            "warm" => false,
            "post_roll_ms" => 150
          })
        end)

      assert log =~
               "hold ended by pointercancel after 840 ms, lost capture: true, mic open: 120 ms, warm: false, post roll: 150 ms"
    end

    test "says when the press was warm", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/talk")

      log =
        capture_log([level: :info], fn ->
          view
          |> element("#talk-button")
          |> render_hook("hold_ended", %{
            "ended_by" => "pointerup",
            "hold_ms" => 1500,
            "lost_capture" => false,
            "mic_open_ms" => 0,
            "warm" => true,
            "post_roll_ms" => 150
          })
        end)

      assert log =~
               "hold ended by pointerup after 1500 ms, lost capture: false, mic open: 0 ms, warm: true, post roll: 150 ms"
    end

    test "says when the hold ended before the mic was live", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/talk")

      log =
        capture_log([level: :info], fn ->
          view
          |> element("#talk-button")
          |> render_hook("hold_ended", %{
            "ended_by" => "pointerup",
            "hold_ms" => 60,
            "warm" => false,
            "post_roll_ms" => 0
          })
        end)

      assert log =~
               "hold ended by pointerup after 60 ms, lost capture: false, mic open: none, warm: false, post roll: 0 ms"
    end

    test "with an unknown ending, a bad length, warm or post roll is ignored", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/talk")

      good = %{"ended_by" => "pointerup", "hold_ms" => 10, "warm" => true, "post_roll_ms" => 0}

      log =
        capture_log([level: :info], fn ->
          for bad <- [
                %{"ended_by" => "<script>"},
                %{"hold_ms" => -1},
                %{"hold_ms" => "5000"},
                %{"warm" => "true"},
                %{"post_roll_ms" => -5},
                %{"post_roll_ms" => "150"}
              ] do
            view |> element("#talk-button") |> render_hook("hold_ended", Map.merge(good, bad))
          end

          for params <- [Map.delete(good, "warm"), Map.delete(good, "post_roll_ms"), %{}] do
            view |> element("#talk-button") |> render_hook("hold_ended", params)
          end
        end)

      refute log =~ "hold ended"
      assert has_element?(view, "#talk-screen[data-state='idle']")
    end
  end

  test "the Talk button's own state is never set from the server's moment", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/talk")
    view |> element("#talk-button") |> render_hook("talk_state", %{"state" => "recording"})

    assert has_element?(view, "#talk-screen[data-state='recording']")
    # Ignored elements still merge server data attributes (LiveView DOM patching), so the
    # button only ever carries the static mount value and the hook restores its own.
    assert has_element?(view, "#talk-button[data-state='idle'][phx-update='ignore']")
  end

  test "the chat shows only the last 3 exchanges, the latest as now", %{conn: conn, guest: guest} do
    for n <- 1..5,
        do: {:ok, _} = Turn.insert(%Turn{guest_id: guest, question: "Q#{n}", answer: "A#{n}"})

    {:ok, view, _html} = live(conn, ~p"/talk")
    html = render(view)

    assert has_element?(view, "#turns #conversation")
    assert count(html, "#conversation .turn") == 3
    assert texts(html, "#conversation .turn .question") == ~w(Q3 Q4 Q5)
    assert count(html, "#conversation .turn.now") == 1
    assert has_element?(view, "#conversation .turn.now .answer", "A5")
  end

  test "a nothing heard Question reads as a friendly line", %{conn: conn, guest: guest} do
    {:ok, _} =
      Turn.insert(%Turn{
        guest_id: guest,
        question: "(nothing heard)",
        answer: "I did not catch that."
      })

    {:ok, view, _html} = live(conn, ~p"/talk")

    assert has_element?(
             view,
             "#conversation .turn .question.nothing-heard",
             "Maya did not hear anything that time"
           )

    refute has_element?(view, "#conversation", "(nothing heard)")
  end

  test "the Talk button has a hidden mic, a hint and a label per moment", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/talk")

    assert has_element?(view, "#talk-button svg[aria-hidden='true']")
    assert has_element?(view, "#talk-button #talk-hint")

    for {show, label} <- [
          {"idle", "Hold to talk"},
          {"recording", "Release to send"},
          {"uploading waiting", "One sec…"},
          {"speaking", "Hold to cut in"}
        ],
        do: assert(has_element?(view, "#talk-button .talk-label [data-show='#{show}']", label))

    assert has_element?(view, "#start-fresh-button")
  end

  test "the Talk button starts idle and is bound to the Talk hook", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/talk")

    assert has_element?(view, "#talk-button[data-state='idle'][phx-hook='TalkHook']")
    assert has_element?(view, "#talk-button[data-sample-rate='24000']")
    assert has_element?(view, "#talk-button[data-post-roll-ms='150']")
    refute has_element?(view, "#conversation .turn")
  end

  test "the screen shows the session guest's turns and no other guest's", %{
    conn: conn,
    guest: guest
  } do
    {:ok, _} = Turn.insert(%Turn{guest_id: guest, question: "Mine", answer: "Yours"})
    {:ok, _} = Turn.insert(%Turn{guest_id: "someone-else", question: "Theirs", answer: "No"})

    {:ok, view, _html} = live(conn, ~p"/talk")

    assert view |> element("#conversation .turn .question") |> render() =~ "Mine"
    refute has_element?(view, "#conversation .turn .question", "Theirs")
  end

  test "a session with no guest reloads the page so the pipeline gives it one" do
    # A fresh conn: the setup conn's test session already holds a guest.
    assert {:error, {:redirect, %{to: "/talk"}}} =
             live_isolated(build_conn(), MayaWeb.TalkLive, session: %{})
  end

  test "Start fresh asks first, then offers a form that posts to /fresh", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/talk")
    refute has_element?(view, "#start-fresh-confirm")

    view |> element("#start-fresh-button") |> render_click()
    assert has_element?(view, "#start-fresh-confirm[action='/fresh'][method='post']")
    assert has_element?(view, "#start-fresh-confirm input[name='_csrf_token']")
    assert has_element?(view, "#start-fresh-confirm #start-fresh-yes[type='submit']")

    view |> element("#keep-talking") |> render_click()
    refute has_element?(view, "#start-fresh-confirm")
    assert has_element?(view, "#start-fresh-button")
  end

  test "a hold streams its audio: no upload form, one Question per hold", %{
    conn: conn,
    guest: guest
  } do
    stub(text("Where is Ralts"), &speak/1)
    {:ok, view, _html} = live(conn, ~p"/talk")
    refute has_element?(view, "#question-form")

    ask(view)
    assert_push_event(view, "audio_done", %{})
    # A late second end for the same hold is ignored.
    view |> element("#talk-button") |> render_hook("stream_end", %{})

    _ = Maya.Conversation.turns(guest)
    assert [%Turn{question: "Where is Ralts", stt_source: "batch"}] = Turn.recent(guest)
  end

  test "partial text shows in the live bubble, then the final Question is pending", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/talk")

    send(view.pid, {:conversation, {:partial, "where do I catch"}})
    assert view |> element("#live-question") |> render() =~ "where do I catch"

    send(view.pid, {:conversation, {:question, "where do I catch Ralts?"}})
    refute has_element?(view, "#live-question")
    assert view |> element("#pending-question") |> render() =~ "where do I catch Ralts?"
    assert has_element?(view, "#conversation[aria-live=polite] #pending-question")

    send(view.pid, {:conversation, {:turns, []}})
    refute has_element?(view, "#pending-question")
  end

  test "one hold is transcribed, answered, spoken and shown", %{conn: conn, guest: guest} do
    stub(text("Where is Ralts"), &speak/1)
    {:ok, view, _html} = live(conn, ~p"/talk")

    ask(view)

    assert_push_event(view, "heard", %{})
    assert_push_event(view, "audio", %{pcm: pcm})
    assert Base.decode64!(pcm) == <<1, 2>>
    assert_push_event(view, "audio_done", %{})

    assert view |> element("#conversation .turn .question") |> render() =~ "Where is Ralts"
    assert view |> element("#conversation .turn .answer") |> render() =~ "Where is Ralts"
    assert has_element?(view, "#trainer-card #badge-case")
    refute has_element?(view, "#poke-facts")
    # A call returns only after the Conversation stored the turn.
    _ = Maya.Conversation.turns(guest)
    assert [%Turn{question: "Where is Ralts"}] = Turn.recent(guest)
  end

  # The agent logs the Event the Question names, then answers with the tool's line.
  defp log_events do
    Req.Test.stub(Maya.OpenRouter, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      last = List.last(Jason.decode!(body)["messages"])

      message =
        case {last["role"], last["content"]} do
          {"tool", content} ->
            %{"role" => "assistant", "content" => content}

          {"user", question} ->
            %{"role" => "assistant", "content" => nil, "tool_calls" => [log_call(question)]}
        end

      Req.Test.json(conn, %{"choices" => [%{"message" => message}]})
    end)
  end

  defp log_call(question) do
    args =
      cond do
        question =~ "badge" ->
          %{"kind" => "badge_earned", "details" => %{"leader" => "Roxanne"}}

        question =~ "caught" ->
          %{"kind" => "caught", "details" => %{"species" => "ralts", "level" => 5}}

        question =~ "Dewford" ->
          %{"kind" => "moved", "details" => %{"location" => "Dewford Town"}}

        true ->
          %{"kind" => "undo"}
      end

    %{
      "id" => "call_#{System.unique_integer([:positive])}",
      "type" => "function",
      "function" => %{"name" => "log_event", "arguments" => Jason.encode!(args)}
    }
  end

  defp ask_and_hear(view, question) do
    stub(text(question), &speak/1)
    ask(view)
    assert_push_event(view, "audio_done", %{})
  end

  test "an Event in a turn updates the trainer card without a reload", %{conn: conn} do
    log_events()
    {:ok, view, _html} = live(conn, ~p"/talk")
    assert has_element?(view, "#badge-count", "0 of 8 badges")

    ask_and_hear(view, "I just earned Roxanne's badge")
    assert has_element?(view, "#badge-count", "1 of 8 badges")
    assert has_element?(view, "#next-gym", "Next gym: Brawly")

    ask_and_hear(view, "I sailed to Dewford")
    assert has_element?(view, "#location", "Dewford Town")

    ask_and_hear(view, "I caught a Ralts at level 5")
    assert has_element?(view, "#team .mon", "Ralts Lv 5")

    ask_and_hear(view, "undo that")
    refute has_element?(view, "#team .mon", "Ralts")
    assert has_element?(view, "#location", "Dewford Town")

    ask_and_hear(view, "undo that too")
    assert has_element?(view, "#location", "Littleroot Town")

    ask_and_hear(view, "and undo the last one")
    assert has_element?(view, "#badge-count", "0 of 8 badges")
    assert has_element?(view, "#next-gym", "Next gym: Roxanne")
  end

  test "a cut after the agent logged an Event still updates the card", %{conn: conn, guest: guest} do
    me = self()

    Req.Test.stub(Maya.OpenRouter, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      case List.last(Jason.decode!(body)["messages"]) do
        %{"role" => "tool"} ->
          send(me, :logged)
          Process.sleep(:infinity)

        %{"content" => question} ->
          message = %{
            "role" => "assistant",
            "content" => nil,
            "tool_calls" => [log_call(question)]
          }

          Req.Test.json(conn, %{"choices" => [%{"message" => message}]})
      end
    end)

    stub(text("I just earned Roxanne's badge"), &speak/1)
    {:ok, view, _html} = live(conn, ~p"/talk")
    ask(view)
    assert_receive :logged

    view |> element("#talk-button") |> render_hook("barge_in", %{})
    _ = Maya.Conversation.turns(guest)
    assert has_element?(view, "#badge-count", "1 of 8 badges")
  end

  test "playback timings are stored, junk values are dropped", %{conn: conn, guest: guest} do
    stub(text("Where is Ralts"), &speak/1)
    {:ok, view, _html} = live(conn, ~p"/talk")
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

    {:ok, view, _html} = live(conn, ~p"/talk")
    ask(view)
    assert_receive :speaking

    view |> element("#talk-button") |> render_hook("barge_in", %{})

    _ = Maya.Conversation.turns(guest)
    assert view |> element("#conversation .turn .cut") |> render() =~ "cut short"
    assert view |> element("#conversation .turn .answer") |> render() =~ "Where is Ralts"
  end

  test "TTS down shows the Answer with a voice is down note", %{conn: conn} do
    stub(text("Where is Ralts"), &Plug.Conn.send_resp(&1, 503, "down"))
    {:ok, view, _html} = live(conn, ~p"/talk")

    ask(view)

    assert_push_event(view, "voice_down", %{})
    assert view |> element("#conversation .turn .voice-down") |> render() =~ "voice is down"
    assert view |> element("#conversation .turn .answer") |> render() =~ "Where is Ralts"
    refute has_element?(view, "#voice-down")
  end

  test "STT down shows the voice is down note on its own", %{conn: conn} do
    stub(&Plug.Conn.send_resp(&1, 500, "down"), &speak/1)
    {:ok, view, _html} = live(conn, ~p"/talk")

    ask(view)

    assert_push_event(view, "voice_down", %{})
    assert view |> element("#voice-down") |> render() =~ "voice is down"
    refute has_element?(view, "#conversation .turn")
  end
end
