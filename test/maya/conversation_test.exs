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
    {:ok, _pid} = Conversation.start_or_find(id)
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
    do: %{"choices" => [%{"message" => %{"role" => "assistant", "content" => answer(content)}}]}

  defp answer(text), do: Jason.encode!(%{answer: text, used_tool_calls: []})

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

    assert_receive {:conversation, {:audio, nil, <<1, 2>>}}
    assert_receive {:conversation, {:audio, nil, <<3, 4>>}}
    assert_receive {:conversation, {:audio_done, nil}}
    assert_receive {:conversation, {:turns, [%Turn{id: turn_id}]}} when is_integer(turn_id)

    [turn] = Turn.recent(id)
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

  test "STT is biased toward known names and the agent gets the corrected Question",
       %{id: id} do
    me = self()

    stub(
      fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        send(me, {:stt_body, body})
        Req.Test.json(conn, %{"text" => "where do I catch rawls?"})
      end,
      &speak/1
    )

    Req.Test.stub(Maya.OpenRouter, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(me, {:agent_body, body})
      Req.Test.json(conn, reply("On Route 102."))
    end)

    Conversation.question(id, "RIFF", "question.wav")

    assert_receive {:stt_body, stt_body}
    assert stt_body =~ ~r/name="context_bias"\r\n(?:[^\r\n]+\r\n)*\r\nMudkip\r\n/
    assert stt_body =~ ~r/name="context_bias"\r\n(?:[^\r\n]+\r\n)*\r\nSootopolis City\r\n/

    assert_receive {:agent_body, agent_body}
    assert agent_body =~ "where do I catch Ralts?"
    # Bias terms steer recognition only: a past-horizon name never reaches the model from them.
    refute agent_body =~ "Sootopolis"

    assert_receive {:conversation, {:turns, [%Turn{id: turn_id}]}} when is_integer(turn_id)
    assert %Turn{question: "where do I catch Ralts?"} = Repo.get!(Turn, turn_id)
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

    assert_receive {:conversation, {:audio_done, nil}}
    assert_receive {:conversation, {:turns, [%Turn{id: turn_id}]}} when is_integer(turn_id)
    assert %Turn{mic_release_ms: 90, playback_start_ms: 1500} = Repo.get!(Turn, turn_id)
  end

  test "agent down: the short error line is spoken and stored", %{id: id} do
    stub(text("How do I earn Roxanne's badge?"), &speak/1)
    Req.Test.stub(Maya.OpenRouter, &Plug.Conn.send_resp(&1, 500, "down"))

    log =
      capture_log(fn ->
        Conversation.question(id, "RIFF", "question.wav")

        assert_receive {:conversation, {:audio, _, _}}
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
    refute_receive {:conversation, {:audio, _, _}}, 100
  end

  test "TTS down: the Answer stays as text with the voice down flag, and is stored", %{id: id} do
    stub(text("Where is Ralts"), &Plug.Conn.send_resp(&1, 503, "down"))

    log =
      capture_log(fn ->
        Conversation.question(id, "RIFF", "question.wav")
        assert_receive {:conversation, :voice_down}
      end)

    # The provider's error body is logged (#96): it says why, the status alone does not.
    assert log =~ ~s([warning] tts failed: {:http, 503, "down"})
    refute log =~ "Ralts"
    assert [%Turn{answer: "Where is Ralts", voice_down: true}] = Conversation.turns(id)
    assert [%Turn{answer: "Where is Ralts"}] = Turn.recent(id)
  end

  test "TTS fails mid-stream after chunks were pushed: voice down, never nothing (#96)", %{id: id} do
    # The second delta is not base64, so the stream's Task crashes after the first chunk went out.
    stub(text("Where is Ralts"), fn conn ->
      body =
        sse("speech.audio.delta", %{"audio_data" => Base.encode64(<<1, 2>>)}) <>
          sse("speech.audio.delta", %{"audio_data" => "not base64!"})

      Plug.Conn.send_resp(conn, 200, body)
    end)

    capture_log(fn ->
      Conversation.question(id, "RIFF", "question.wav")
      assert_receive {:conversation, {:audio, nil, <<1, 2>>}}
      assert_receive {:conversation, :voice_down}
    end)

    refute_received {:conversation, {:audio_done, _}}
    assert [%Turn{answer: "Where is Ralts", voice_down: true}] = Conversation.turns(id)
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
    assert Turn.recent(id) == []
  end

  # Postgres down or paused (#82): the shared sandbox is switched off, so every query from the
  # Conversation and its Tasks fails the way a lost pool does, with no row data in the error.
  defp db_down, do: Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)

  test "Progress unreadable: Maya says her notes are offline, never voice down (#82)", %{id: id} do
    stub(text("Where is Ralts"), &speak/1)
    Req.Test.stub(Maya.OpenRouter, fn _conn -> flunk("the agent was called") end)
    db_down()

    log =
      capture_log(fn ->
        Conversation.question(id, "RIFF", "question.wav")
        assert_receive {:conversation, {:question, "Where is Ralts"}}
        assert_receive {:conversation, {:audio_done, nil}}

        assert [
                 %Turn{
                   question: "Where is Ralts",
                   answer: "I can't reach my notes right now" <> _
                 }
               ] =
                 Conversation.turns(id)
      end)

    refute_received {:conversation, :voice_down}
    assert log =~ "[warning] progress failed: DBConnection.OwnershipError"
    assert log =~ "[warning] store failed: DBConnection.OwnershipError"
    refute log =~ "Ralts"
  end

  test "storing the turn fails: Maya still answers and the turn stays on screen (#82)", %{id: id} do
    me = self()

    stub(text("Where is Ralts"), fn conn ->
      send(me, {:tts_pid, self()})
      assert_receive :go
      speak(conn)
    end)

    Conversation.question(id, "RIFF", "question.wav")
    assert_receive {:tts_pid, tts_pid}
    db_down()

    log =
      capture_log(fn ->
        send(tts_pid, :go)
        assert_receive {:conversation, {:audio_done, nil}}
        assert [%Turn{id: nil, answer: "Where is Ralts"}] = Conversation.turns(id)
      end)

    refute_received {:conversation, :voice_down}
    assert log =~ "[warning] store failed: DBConnection.OwnershipError"
  end

  test "storing the timings fails: they stay in memory, never a crash (#82)", %{id: id} do
    stub(text("Where is Ralts"), &speak/1)
    Conversation.question(id, "RIFF", "question.wav")
    assert_receive {:conversation, {:turns, [%Turn{id: turn_id}]}} when is_integer(turn_id)
    db_down()

    log =
      capture_log(fn ->
        Conversation.playback_started(id, %{mic_release_ms: 180, playback_start_ms: 2400})

        assert [%Turn{id: ^turn_id, playback_start_ms: 2400}] = Conversation.turns(id)
      end)

    assert log =~ "[warning] timings failed: DBConnection.OwnershipError"
  end

  test "a Conversation that starts while Postgres is down starts with no turns (#82)" do
    db_down()
    other = "down-#{System.unique_integer([:positive])}"
    on_exit(fn -> Conversation.stop(other) end)

    log =
      capture_log(fn ->
        assert {:ok, _pid} = Conversation.start_or_find(other)
        assert Conversation.turns(other) == []
      end)

    assert log =~ "[warning] turns failed: DBConnection.OwnershipError"
  end

  test "a crashed Conversation restarts under the same name and reloads its turns", %{id: id} do
    {:ok, _} = Turn.insert(%Turn{guest_id: id, question: "Where is Ralts", answer: "Route 102"})
    {:ok, pid} = Conversation.start_or_find(id)
    ref = Process.monitor(pid)

    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^ref, :process, ^pid, :killed}

    assert restarted(id, pid) != pid
    assert [%Turn{question: "Where is Ralts"}] = Conversation.turns(id)
  end

  test "two guests get two Conversations and never see each other's turns", %{id: id} do
    other = "other-#{System.unique_integer([:positive])}"
    {:ok, other_pid} = Conversation.start_or_find(other)
    on_exit(fn -> Conversation.stop(other) end)
    {:ok, pid} = Conversation.start_or_find(id)
    assert pid != other_pid

    stub(text("Where is Ralts"), &speak/1)
    Conversation.question(id, "RIFF", "question.wav")
    assert_receive {:conversation, {:turns, [%Turn{id: turn_id}]}} when is_integer(turn_id)

    assert [%Turn{guest_id: ^id}] = Turn.recent(id)
    assert Conversation.turns(other) == []
    assert Turn.recent(other) == []
  end

  test "after the idle time the Conversation stops for good, and a Question starts it again" do
    idle_id = "idle-#{System.unique_integer([:positive])}"
    Application.put_env(:maya, :conversation_idle_ms, 50)
    on_exit(fn -> Application.delete_env(:maya, :conversation_idle_ms) end)

    {:ok, _} =
      Turn.insert(%Turn{guest_id: idle_id, question: "Where is Ralts", answer: "Route 102"})

    {:ok, pid} = Conversation.start_or_find(idle_id)
    on_exit(fn -> Conversation.stop(idle_id) end)
    ref = Process.monitor(pid)

    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 1_000
    # Not restarted: the supervisor has no child left (transient, normal exit).
    assert DynamicSupervisor.which_children(Maya.ConversationSupervisor)
           |> Enum.all?(fn {_, child, _, _} -> child != pid end)

    Application.delete_env(:maya, :conversation_idle_ms)
    Conversation.subscribe(idle_id)
    stub(text("Hi"), &speak/1)
    Conversation.question(idle_id, "RIFF", "question.wav")

    assert_receive {:conversation, {:turns, [%Turn{question: "Where is Ralts"}, %Turn{id: id}]}}
                   when is_integer(id)
  end

  test "after a restart with 30 stored turns, the screen and the next agent request get 25" do
    id = "test-#{System.unique_integer([:positive])}"

    for n <- 1..30,
        do: {:ok, _} = Turn.insert(%Turn{guest_id: id, question: "q#{n}", answer: "a#{n}"})

    me = self()

    Req.Test.stub(Maya.OpenRouter, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(me, {:agent_messages, Jason.decode!(body)["messages"]})
      Req.Test.json(conn, reply("Hi"))
    end)

    {:ok, _pid} = Conversation.start_or_find(id)
    on_exit(fn -> Conversation.stop(id) end)
    turns = Conversation.turns(id)
    assert length(turns) == 25
    assert hd(turns).question == "q6"

    Conversation.subscribe(id)
    stub(text("Next one"), &speak/1)
    Conversation.question(id, "RIFF", "question.wav")

    assert_receive {:agent_messages, [%{"role" => "system"} | rest]}
    assert length(rest) == 51
    assert hd(rest) == %{"role" => "user", "content" => "q6"}

    # The screen keeps 25: the new turn pushes out the oldest.
    assert_receive {:conversation, {:turns, after_turns}}
    assert length(after_turns) == 25
    assert hd(after_turns).question == "q7"
  end

  # The supervisor restarts the Conversation; wait for the new pid in the Registry.
  defp restarted(id, old, tries \\ 50) do
    case Registry.lookup(Maya.ConversationRegistry, {:conversation, id}) do
      [{pid, _}] when pid != old -> pid
      _ when tries > 0 -> Process.sleep(10) && restarted(id, old, tries - 1)
    end
  end
end
