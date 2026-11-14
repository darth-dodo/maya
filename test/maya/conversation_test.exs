defmodule Maya.ConversationTest do
  # Not async: the Conversation and its Tasks run outside the test process (shared sandbox and stubs).
  use Maya.DataCase, async: false

  import ExUnit.CaptureLog

  alias Maya.Conversation
  alias Maya.Voice.Turn

  setup {Req.Test, :set_req_test_to_shared}

  setup do
    :ok = Maya.GameData.import!()
    # The agent answers by repeating the Question unless a test stubs it otherwise.
    Req.Test.stub(Maya.OpenRouter, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      %{"messages" => messages} = Jason.decode!(body)
      Req.Test.json(conn, reply(List.last(messages)["content"]))
    end)

    id = "test-#{System.unique_integer([:positive])}"
    {:ok, _pid} = Conversation.ensure_started(id)
    on_exit(fn -> Conversation.stop(id) end)
    Conversation.subscribe(id)
    %{id: id}
  end

  defp sse(type, extra),
    do: "event: #{type}\ndata: #{Jason.encode!(Map.put(extra, "type", type))}\n\n"

  # STT answers `stt`; TTS runs `tts` (a fun of the conn).
  defp stub(stt, tts) do
    Req.Test.stub(Maya.Mistral, fn
      %{request_path: "/v1/audio/transcriptions"} = conn -> stt.(conn)
      %{request_path: "/v1/audio/speech"} = conn -> tts.(conn)
    end)
  end

  defp reply(content),
    do: %{"choices" => [%{"message" => %{"role" => "assistant", "content" => content}}]}

  defp text(text), do: &Req.Test.json(&1, %{"text" => text})

  defp speak(conn) do
    body =
      sse("speech.audio.delta", %{"audio_data" => Base.encode64(<<1, 2>>)}) <>
        sse("speech.audio.delta", %{"audio_data" => Base.encode64(<<3, 4>>)}) <>
        sse("speech.audio.done", %{})

    conn |> Plug.Conn.put_resp_content_type("text/event-stream") |> Plug.Conn.send_resp(200, body)
  end

  test "a Question is transcribed, answered by the agent, spoken and stored with stage timings",
       %{id: id} do
    answer = "Lead with Mudkip against Nosepass. Mudkip would approve."
    stub(text("How do I earn Roxanne's badge?"), &speak/1)
    Req.Test.stub(Maya.OpenRouter, &Req.Test.json(&1, reply(answer)))

    Conversation.question(id, "RIFF", "question.wav")

    assert_receive {:conversation, {:audio, <<1, 2>>}}
    assert_receive {:conversation, {:audio, <<3, 4>>}}
    assert_receive {:conversation, :audio_done}
    assert_receive {:conversation, {:turns, [%Turn{id: turn_id}]}} when is_integer(turn_id)

    [turn] = Turn.recent()
    assert turn.question == "How do I earn Roxanne's badge?"
    assert turn.answer == answer
    refute turn.cut
    assert turn.stt_ms >= 0
    assert turn.agent_ms >= 0
    assert turn.tts_first_byte_ms >= 0

    Conversation.playback_started(id, %{mic_release_ms: 180, playback_start_ms: 2400})
    assert [%Turn{id: ^turn_id}] = Conversation.turns(id)

    assert %Turn{mic_release_ms: 180, playback_start_ms: 2400} = Repo.get!(Turn, turn_id)
  end

  test "playback timings that arrive before the stream ends are stored with the turn", %{id: id} do
    me = self()

    stub(text("Hi"), fn conn ->
      send(me, {:tts_pid, self()})
      receive do: (:go -> speak(conn))
    end)

    Conversation.question(id, "RIFF", "question.wav")
    assert_receive {:tts_pid, tts_pid}
    Conversation.playback_started(id, %{mic_release_ms: 90, playback_start_ms: 1500})
    _ = Conversation.turns(id)
    send(tts_pid, :go)

    assert_receive {:conversation, :audio_done}
    assert_receive {:conversation, {:turns, [%Turn{id: turn_id}]}} when is_integer(turn_id)
    assert %Turn{mic_release_ms: 90, playback_start_ms: 1500} = Repo.get!(Turn, turn_id)
  end

  test "agent down: the short error line is spoken and stored", %{id: id} do
    stub(text("How do I earn Roxanne's badge?"), &speak/1)
    Req.Test.stub(Maya.OpenRouter, &Plug.Conn.send_resp(&1, 500, "down"))

    log =
      capture_log(fn ->
        Conversation.question(id, "RIFF", "question.wav")

        assert_receive {:conversation, {:audio, _}}
        assert_receive {:conversation, {:turns, [%Turn{id: turn_id}]}} when is_integer(turn_id)
        assert %Turn{answer: "Lost my train of thought, ask again?"} = Repo.get!(Turn, turn_id)
      end)

    assert log =~ "[warning] agent failed: {:http, 500}"
    refute log =~ "Roxanne"
  end

  test "a crashed agent Task logs its exception and the error line is spoken", %{id: id} do
    stub(text("How do I earn Roxanne's badge?"), &speak/1)
    Req.Test.stub(Maya.OpenRouter, fn _conn -> raise "boom" end)

    log =
      capture_log(fn ->
        Conversation.question(id, "RIFF", "question.wav")

        assert_receive {:conversation, {:turns, [%Turn{id: turn_id}]}} when is_integer(turn_id)
        assert %Turn{answer: "Lost my train of thought, ask again?"} = Repo.get!(Turn, turn_id)
      end)

    assert log =~ "[warning] agent failed: boom"
  end

  test "an empty transcript is answered without calling the agent", %{id: id} do
    stub(text("  "), &speak/1)
    Req.Test.stub(Maya.OpenRouter, fn _conn -> flunk("the agent was called") end)

    Conversation.question(id, "RIFF", "question.wav")

    assert_receive {:conversation, {:turns, [%Turn{id: turn_id}]}} when is_integer(turn_id)

    assert %Turn{question: "(nothing heard)", answer: "I did not catch that."} =
             Repo.get!(Turn, turn_id)
  end

  test "barge-in while the agent thinks drops the turn", %{id: id} do
    me = self()
    stub(text("Where is Ralts"), &speak/1)

    Req.Test.stub(Maya.OpenRouter, fn conn ->
      send(me, {:agent_pid, self()})
      Process.sleep(:infinity)
      conn
    end)

    Conversation.question(id, "RIFF", "question.wav")
    assert_receive {:agent_pid, agent_pid}
    ref = Process.monitor(agent_pid)

    Conversation.barge_in(id)

    assert_receive {:DOWN, ^ref, :process, ^agent_pid, _}
    assert Conversation.turns(id) == []
  end

  test "barge-in cancels the TTS stream, keeps the Answer as text and marks it cut", %{id: id} do
    me = self()

    stub(text("Where is Ralts"), fn conn ->
      send(me, {:tts_pid, self()})
      Process.sleep(:infinity)
      conn
    end)

    Conversation.question(id, "RIFF", "question.wav")
    assert_receive {:tts_pid, tts_pid}
    ref = Process.monitor(tts_pid)

    Conversation.barge_in(id)

    assert_receive {:DOWN, ^ref, :process, ^tts_pid, _}

    assert_receive {:conversation, {:turns, [%Turn{cut: true, id: turn_id}]}}
                   when is_integer(turn_id)

    assert %Turn{cut: true, answer: "Where is Ralts"} = Repo.get!(Turn, turn_id)
    refute_receive {:conversation, {:audio, _}}, 100
  end

  test "TTS down: the Answer stays as text with the voice down flag, and is stored", %{id: id} do
    stub(text("Where is Ralts"), &Plug.Conn.send_resp(&1, 503, "down"))

    log =
      capture_log(fn ->
        Conversation.question(id, "RIFF", "question.wav")
        assert_receive {:conversation, :voice_down}
      end)

    assert log =~ "[warning] tts failed: {:http, 503}"
    refute log =~ "Ralts"
    assert [%Turn{answer: "Where is Ralts", voice_down: true}] = Conversation.turns(id)
    assert [%Turn{answer: "Where is Ralts"}] = Turn.recent()
  end

  test "STT down: voice down and no turn", %{id: id} do
    stub(&Plug.Conn.send_resp(&1, 500, "down"), &speak/1)

    log =
      capture_log(fn ->
        Conversation.question(id, "RIFF", "question.wav")
        assert_receive {:conversation, :voice_down}
      end)

    assert log =~ "[warning] stt failed: {:http, 500}"
    assert Conversation.turns(id) == []
    assert Turn.recent() == []
  end

  test "a crashed Conversation restarts under the same name and reloads its turns", %{id: id} do
    {:ok, _} = Turn.insert(%Turn{question: "Where is Ralts", answer: "Route 102"})
    {:ok, pid} = Conversation.ensure_started(id)
    ref = Process.monitor(pid)

    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^ref, :process, ^pid, :killed}

    assert restarted(id, pid) != pid
    assert [%Turn{question: "Where is Ralts"}] = Conversation.turns(id)
  end

  # The supervisor restarts the Conversation; wait for the new pid in the Registry.
  defp restarted(id, old, tries \\ 50) do
    case Registry.lookup(Maya.ConversationRegistry, id) do
      [{pid, _}] when pid != old -> pid
      _ when tries > 0 -> Process.sleep(10) && restarted(id, old, tries - 1)
    end
  end
end
