defmodule Maya.ConversationStreamTest do
  # Streamed Questions (openspec realtime-transcription). Not async: the Conversation, its
  # Tasks and the fake realtime endpoint run outside the test process.
  use Maya.DataCase, async: false

  import ExUnit.CaptureLog

  alias Maya.Conversation
  alias Maya.FakeMistralRealtime
  alias Maya.Voice.Turn

  setup {Req.Test, :set_req_test_to_shared}

  setup do
    :ok = Maya.GameData.import!()
    me = self()

    # The agent repeats the Question and reports each call.
    Req.Test.stub(Maya.OpenRouter, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      question = List.last(Jason.decode!(body)["messages"])["content"]
      send(me, {:agent_called, question})
      message = %{"role" => "assistant", "content" => question}
      Req.Test.json(conn, %{"choices" => [%{"message" => message}]})
    end)

    id = "stream-#{System.unique_integer([:positive])}"
    {:ok, _pid} = Conversation.start_or_find(id)
    on_exit(fn -> Conversation.stop(id) end)
    Conversation.subscribe(id)
    %{id: id}
  end

  # Batch STT answers `text` and reports the uploaded file; TTS speaks one chunk.
  defp batch(text) do
    me = self()

    Req.Test.stub(Maya.Mistral, fn
      %{request_path: "/v1/audio/transcriptions"} = conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        send(me, {:batch_body, body})
        Req.Test.json(conn, %{"text" => text})

      %{request_path: "/v1/audio/speech"} = conn ->
        body =
          "event: speech.audio.done\ndata: #{Jason.encode!(%{type: "speech.audio.done"})}\n\n"

        Plug.Conn.send_resp(conn, 200, body)
    end)
  end

  defp voice(opts) do
    voice = Application.fetch_env!(:maya, :voice)
    Application.put_env(:maya, :voice, Keyword.merge(voice, opts))
    on_exit(fn -> Application.put_env(:maya, :voice, voice) end)
  end

  defp hold(id, chunks) do
    Conversation.stream_start(id)
    for pcm <- chunks, do: Conversation.audio_chunk(id, Base.encode64(pcm))
    Conversation.stream_end(id)
  end

  defp stored do
    assert_receive {:conversation, :audio_done}
    assert_receive {:conversation, {:turns, [%Turn{id: turn_id}]}} when is_integer(turn_id)
    Repo.get!(Turn, turn_id)
  end

  test "realtime off: the streamed audio goes to batch STT as one WAV, once per hold", %{id: id} do
    batch("Where is Ralts?")
    hold(id, [<<1, 0, 2, 0>>, <<3, 0>>])
    Conversation.stream_end(id)

    assert_receive {:batch_body, body}
    assert body =~ "RIFF"
    assert body =~ <<"data", 6::little-32, 1, 0, 2, 0, 3, 0>>
    assert_receive {:conversation, {:question, "Where is Ralts?"}}

    assert %Turn{question: "Where is Ralts?", stt_source: "batch", stt_ms: ms} = stored()
    assert ms >= 0
    refute_receive {:batch_body, _}, 100
    assert [_one] = Turn.recent(id)
  end

  test "bad, oversized and over the cap chunks are dropped and logged without audio", %{id: id} do
    batch("Where is Ralts?")

    log =
      capture_log(fn ->
        Conversation.stream_start(id)
        Conversation.audio_chunk(id, "not base64!")
        Conversation.audio_chunk(id, Base.encode64(:binary.copy(<<7>>, 20_480)))

        for _ <- 1..63,
            do: Conversation.audio_chunk(id, Base.encode64(:binary.copy(<<1>>, 16_000)))

        Conversation.stream_end(id)
        # The plug test adapter hands over an empty body past about 1 MB, so count the drops.
        assert_receive {:batch_body, _body}
      end)

    # 62 chunks of 16,000 bytes fit under 1 MB; only the 63rd goes over.
    assert length(String.split(log, ":over_question_cap")) == 2
    assert log =~ "[warning] audio chunk dropped: :bad_base64"
    assert log =~ "[warning] audio chunk dropped: :too_big, 20480 bytes"
    assert log =~ "[warning] audio chunk dropped: :over_question_cap, 16000 bytes"
  end

  test "realtime final: partials show live, the agent waits for release, no batch call", %{
    id: id
  } do
    voice(stt_realtime: true, stt_final: :realtime)
    FakeMistralRealtime.serve(:ok)

    Req.Test.stub(Maya.Mistral, fn
      %{request_path: "/v1/audio/transcriptions"} -> flunk("batch STT was called")
      %{request_path: "/v1/audio/speech"} = conn -> Plug.Conn.send_resp(conn, 200, "")
    end)

    Conversation.stream_start(id)
    for _ <- 1..3, do: Conversation.audio_chunk(id, Base.encode64(<<0::3200*16>>))

    assert_receive {:fake_got, %{"type" => "session.update"}}
    assert_receive {:conversation, {:partial, "where do"}}
    assert_receive {:conversation, {:partial, "where do I catch"}}
    assert_receive {:conversation, {:partial, "where do I catch Ralts"}}
    refute_received {:agent_called, _}

    Conversation.stream_end(id)
    assert_receive {:fake_got, %{"type" => "input_audio.end"}}
    assert_receive {:agent_called, "where do I catch Ralts"}
    assert_receive {:conversation, {:turns, [%Turn{id: turn_id}]}} when is_integer(turn_id)

    assert %Turn{stt_source: "realtime", question: "where do I catch Ralts"} =
             Repo.get!(Turn, turn_id)
  end

  test "batch final keeps realtime as the live preview only", %{id: id} do
    voice(stt_realtime: true, stt_final: :batch)
    FakeMistralRealtime.serve(:ok)
    batch("Where do I catch Ralts?")

    Conversation.stream_start(id)
    Conversation.audio_chunk(id, Base.encode64(<<0::3200*16>>))
    assert_receive {:conversation, {:partial, "where do"}}
    Conversation.stream_end(id)

    assert_receive {:batch_body, _}
    assert %Turn{stt_source: "batch", question: "Where do I catch Ralts?"} = stored()
  end

  test "batch final: release ends the realtime audio once and the last words reach the preview",
       %{id: id} do
    voice(stt_realtime: true, stt_final: :batch)
    FakeMistralRealtime.serve(:ok)
    me = self()

    # Batch answers late, so the late realtime words can show first.
    Req.Test.stub(Maya.Mistral, fn
      %{request_path: "/v1/audio/transcriptions"} = conn ->
        send(me, :batch_called)
        Process.sleep(300)
        Req.Test.json(conn, %{"text" => "Where do I catch Ralts?"})

      %{request_path: "/v1/audio/speech"} = conn ->
        Plug.Conn.send_resp(conn, 200, "")
    end)

    Conversation.stream_start(id)
    Conversation.audio_chunk(id, Base.encode64(<<0::3200*16>>))
    assert_receive {:conversation, {:partial, "where do"}}
    Conversation.stream_end(id)
    Conversation.stream_end(id)

    assert_receive {:fake_got, %{"type" => "input_audio.end"}}
    assert_receive :batch_called
    assert_receive {:conversation, {:partial, "where do I catch"}}
    assert_receive {:conversation, {:partial, "where do I catch Ralts"}}
    assert_receive {:conversation, {:question, "Where do I catch Ralts?"}}
    refute_received {:fake_got, %{"type" => "input_audio.end"}}
    refute_receive {:conversation, {:partial, _}}, 100
  end

  test "a refused realtime connection falls back to batch and logs the reason", %{id: id} do
    voice(stt_realtime: true, stt_final: :realtime)
    FakeMistralRealtime.point_relay_at("ws://127.0.0.1:1/v1/audio/transcriptions/realtime")
    batch("where do I catch Ralts?")

    log =
      capture_log(fn ->
        hold(id, [<<0::3200*16>>])
        assert %Turn{stt_source: "batch", question: "where do I catch Ralts?"} = stored()
      end)

    assert log =~ "[warning] stt_realtime failed: "
    refute log =~ "Ralts"
  end

  test "no transcription.done in time closes the session and batch takes over", %{id: id} do
    voice(stt_realtime: true, stt_final: :realtime, stt_realtime_done_ms: 100)
    FakeMistralRealtime.serve(:stall)
    batch("where do I catch Ralts?")

    log =
      capture_log(fn ->
        Conversation.stream_start(id)
        assert_receive {:fake_socket, socket}
        mon = Process.monitor(socket)
        Conversation.audio_chunk(id, Base.encode64(<<0::3200*16>>))
        Conversation.stream_end(id)

        assert_receive {:DOWN, ^mon, :process, ^socket, _}, 1_000
        assert %Turn{stt_source: "batch"} = stored()
      end)

    assert log =~ "[warning] stt_realtime failed: :done_timeout"
  end

  test "a new hold closes the previous realtime session", %{id: id} do
    voice(stt_realtime: true)
    FakeMistralRealtime.serve(:stall)

    Conversation.stream_start(id)
    assert_receive {:fake_socket, first}
    mon = Process.monitor(first)

    Conversation.stream_start(id)
    assert_receive {:DOWN, ^mon, :process, ^first, _}, 1_000
    assert_receive {:fake_socket, _second}
  end
end
