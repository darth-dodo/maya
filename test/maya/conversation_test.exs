defmodule Maya.ConversationTest do
  # Not async: the Conversation and its Tasks run outside the test process (shared sandbox and stubs).
  use Maya.DataCase, async: false

  alias Maya.Conversation
  alias Maya.Voice.Turn

  setup {Req.Test, :set_req_test_to_shared}

  setup do
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

  defp text(text), do: &Req.Test.json(&1, %{"text" => text})

  defp speak(conn) do
    body =
      sse("speech.audio.delta", %{"audio_data" => Base.encode64(<<1, 2>>)}) <>
        sse("speech.audio.delta", %{"audio_data" => Base.encode64(<<3, 4>>)}) <>
        sse("speech.audio.done", %{})

    conn |> Plug.Conn.put_resp_content_type("text/event-stream") |> Plug.Conn.send_resp(200, body)
  end

  test "a Question is transcribed, echoed, spoken and stored with stage timings", %{id: id} do
    stub(text("How do I earn the first badge"), &speak/1)

    Conversation.question(id, "RIFF", "question.wav")

    assert_receive {:conversation, {:audio, <<1, 2>>}}
    assert_receive {:conversation, {:audio, <<3, 4>>}}
    assert_receive {:conversation, :audio_done}
    assert_receive {:conversation, {:turns, [%Turn{id: turn_id}]}} when is_integer(turn_id)

    [turn] = Turn.recent()
    assert turn.question == "How do I earn the first badge"
    assert turn.answer == "How do I earn the first badge"
    refute turn.cut
    assert turn.stt_ms >= 0
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

  test "an empty transcript is answered with a short line", %{id: id} do
    stub(text("  "), &speak/1)

    Conversation.question(id, "RIFF", "question.wav")

    # The stored turn is broadcast after :audio_done; wait for it before reading the table.
    assert_receive {:conversation, {:turns, [%Turn{id: id}]}} when is_integer(id)
    assert [%Turn{answer: "I did not catch that."}] = Turn.recent()
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

    Conversation.question(id, "RIFF", "question.wav")

    assert_receive {:conversation, :voice_down}
    assert [%Turn{answer: "Where is Ralts", voice_down: true}] = Conversation.turns(id)
    assert [%Turn{answer: "Where is Ralts"}] = Turn.recent()
  end

  test "STT down: voice down and no turn", %{id: id} do
    stub(&Plug.Conn.send_resp(&1, 500, "down"), &speak/1)

    Conversation.question(id, "RIFF", "question.wav")

    assert_receive {:conversation, :voice_down}
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
