defmodule Maya.Voice.MistralTest do
  # Not async: one test changes the :mistral app env.
  use ExUnit.Case, async: false

  alias Maya.Voice.{STT, TTS}

  defp sse(type, extra),
    do: "event: #{type}\ndata: #{Jason.encode!(Map.put(extra, "type", type))}\n\n"

  describe "STT.transcribe/2" do
    test "posts the clip as multipart with the configured model and returns the text" do
      Req.Test.stub(Maya.Mistral, fn conn ->
        assert conn.method == "POST"
        assert conn.request_path == "/v1/audio/transcriptions"
        assert Plug.Conn.get_req_header(conn, "authorization") == ["Bearer test-key"]
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert body =~ "voxtral-mini-transcribe-3"
        assert body =~ ~s(filename="question.wav")
        assert body =~ "RIFFclip"
        Req.Test.json(conn, %{"text" => " How do I earn the first badge \n", "model" => "x"})
      end)

      assert STT.transcribe("RIFFclip", "question.wav") == {:ok, "How do I earn the first badge"}
    end

    test "pins the transcription language to English" do
      Req.Test.stub(Maya.Mistral, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert body =~ ~r/name="language"\r\n(?:[^\r\n]+\r\n)*\r\nen\r\n/
        Req.Test.json(conn, %{"text" => "Hi"})
      end)

      assert STT.transcribe("RIFF", "q.wav") == {:ok, "Hi"}
    end

    test "sends one context_bias field per term" do
      terms = ["Maya", "Ralts", "Rustboro City"]
      me = self()

      Req.Test.stub(Maya.Mistral, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        fields = Regex.scan(~r/name="context_bias"\r\n(?:[^\r\n]+\r\n)*\r\n([^\r\n]*)\r\n/, body)
        send(me, {:bias, Enum.map(fields, &List.last/1), byte_size(body)})
        Req.Test.json(conn, %{"text" => "Hi"})
      end)

      assert STT.transcribe("RIFF", "q.wav", terms) == {:ok, "Hi"}
      assert_received {:bias, ^terms, size}
      # Three short fields add a few hundred bytes of multipart framing, nothing more.
      assert size < 1_500
    end

    test "an HTTP error is an error tuple" do
      Req.Test.stub(Maya.Mistral, &Plug.Conn.send_resp(&1, 500, "down"))
      assert STT.transcribe("RIFF", "question.wav") == {:error, {:http, 500}}
    end

    test "a transport error is an error tuple" do
      Req.Test.stub(Maya.Mistral, &Req.Test.transport_error(&1, :timeout))
      assert {:error, %Req.TransportError{reason: :timeout}} = STT.transcribe("RIFF", "q.wav")
    end

    test "a missing key is an error without a request" do
      old = Application.fetch_env!(:maya, :mistral)
      Application.put_env(:maya, :mistral, Keyword.put(old, :api_key, nil))
      on_exit(fn -> Application.put_env(:maya, :mistral, old) end)

      assert STT.transcribe("RIFF", "q.wav") == {:error, :no_api_key}
    end
  end

  describe "TTS.stream/2" do
    test "asks for a pcm stream and hands each decoded chunk over in order" do
      Req.Test.stub(Maya.Mistral, fn conn ->
        assert conn.request_path == "/v1/audio/speech"
        {:ok, body, conn} = Plug.Conn.read_body(conn)

        assert %{
                 "input" => "Hello",
                 "model" => "voxtral-mini-tts-3-0",
                 "voice_id" => "01a135c4-d896-70d9-a498-2db10c5915ff",
                 "response_format" => "pcm",
                 "stream" => true
               } = Jason.decode!(body)

        events =
          sse("speech.audio.delta", %{"audio_data" => Base.encode64(<<1, 2>>)}) <>
            sse("speech.audio.delta", %{"audio_data" => Base.encode64(<<3, 4>>)}) <>
            sse("speech.audio.done", %{"usage" => %{}})

        {a, b} = String.split_at(events, 37)
        conn = Plug.Conn.send_chunked(conn, 200)
        {:ok, conn} = Plug.Conn.chunk(conn, a)
        {:ok, conn} = Plug.Conn.chunk(conn, b)
        conn
      end)

      me = self()
      assert TTS.stream("Hello", &send(me, {:pcm, &1})) == :ok
      assert_received {:pcm, <<1, 2>>}
      assert_received {:pcm, <<3, 4>>}
      refute_received {:pcm, _}
    end

    test "an HTTP error is an error tuple with the provider's reason and hands over nothing" do
      Req.Test.stub(Maya.Mistral, &Plug.Conn.send_resp(&1, 401, ~s({"message":"no"})))
      me = self()

      assert TTS.stream("Hello", &send(me, {:pcm, &1})) ==
               {:error, {:http, 401, ~s({"message":"no"})}}

      refute_received {:pcm, _}
    end

    test "keeps only the first 500 bytes of an error body (#96)" do
      Req.Test.stub(Maya.Mistral, fn conn ->
        conn = Plug.Conn.send_chunked(conn, 400)
        {:ok, conn} = Plug.Conn.chunk(conn, String.duplicate("a", 300))
        {:ok, conn} = Plug.Conn.chunk(conn, String.duplicate("b", 300))
        conn
      end)

      assert {:error, {:http, 400, body}} = TTS.stream("Hello", fn _ -> :ok end)
      assert body == String.duplicate("a", 300) <> String.duplicate("b", 200)
    end

    test "an error body that echoes the input never carries the Answer" do
      Req.Test.stub(
        Maya.Mistral,
        &Plug.Conn.send_resp(&1, 422, ~s({"input":"Ralts is on Route 102"}))
      )

      assert TTS.stream("Ralts is on Route 102", fn _ -> :ok end) ==
               {:error, {:http, 422, ~s({"input":"[input]"})}}
    end

    # Voxtral speech is mono 24 kHz; `pcm` streams float32 little-endian samples
    # (https://docs.mistral.ai/studio-api/audio, the 2026-11-14 spike in #48). The hook plays
    # pushed PCM at this rate, so a wrong value is garbled or pitched audio (#96).
    test "the configured TTS sample rate and format match the Voxtral docs" do
      assert Application.fetch_env!(:maya, :voice)[:tts_sample_rate] == 24_000

      Req.Test.stub(Maya.Mistral, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        assert %{"response_format" => "pcm", "stream" => true} = Jason.decode!(body)
        Plug.Conn.send_resp(conn, 200, sse("speech.audio.done", %{}))
      end)

      assert TTS.stream("Hello", fn _ -> :ok end) == :ok
    end
  end
end
