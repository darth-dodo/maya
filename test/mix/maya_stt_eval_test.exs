defmodule Mix.Tasks.Maya.SttEvalTest do
  # Fakes only: TTS and batch STT through Req.Test, realtime through the fake endpoint.
  use Maya.DataCase, async: false

  alias Maya.FakeMistralRealtime
  alias Mix.Tasks.Maya.SttEval

  setup {Req.Test, :set_req_test_to_shared}

  setup do
    :ok = Maya.GameData.import!()
    # 100 ms of 24 kHz float32 silence: one 100 ms chunk at 16 kHz, so pacing stays short.
    pcm = :binary.copy(<<0.0::little-float-32>>, 2_400)
    done = "event: speech.audio.done\ndata: {\"type\":\"speech.audio.done\"}\n\n"

    delta =
      "event: speech.audio.delta\ndata: " <>
        Jason.encode!(%{type: "speech.audio.delta", audio_data: Base.encode64(pcm)}) <> "\n\n"

    Req.Test.stub(Maya.Mistral, fn
      %{request_path: "/v1/audio/speech"} = conn ->
        Plug.Conn.send_resp(conn, 200, delta <> done)

      %{request_path: "/v1/audio/transcriptions"} = conn ->
        Req.Test.json(conn, %{"text" => "Where do I catch Ralts?"})
    end)

    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)
    # The task sets the TTS voice and delay in app config; put them back.
    voice = Application.fetch_env!(:maya, :voice)
    on_exit(fn -> Application.put_env(:maya, :voice, voice) end)
    dir = Path.join(System.tmp_dir!(), "stt-eval-#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf!(dir) end)
    %{dir: dir}
  end

  defp lines do
    receive do
      {:mix_shell, :info, [line]} -> [line | lines()]
    after
      0 -> []
    end
  end

  test "spike prints the events and the end to done time" do
    FakeMistralRealtime.serve(:ok)
    SttEval.run(["spike"])
    out = Enum.join(lines(), "\n")

    assert out =~ "spoken: 3200 bytes, 100 ms of audio"
    assert out =~ "events: session.created, 3 transcription.text.delta, transcription.done"
    assert out =~ "transcript: where do I catch Ralts"
    assert out =~ ~r/input_audio.end to transcription.done: \d+ ms/
  end

  test "spike stops on a refused key" do
    FakeMistralRealtime.serve(:unauthorized)

    assert_raise Mix.Error, ~r/HTTP 401: stop and report on #75/, fn -> SttEval.run(["spike"]) end
  end

  test "fixtures, then the eval: per clip and total numbers and the gate's pick", %{dir: dir} do
    FakeMistralRealtime.serve(:ok, [])
    SttEval.run(["fixtures", "--dir", dir, "--voices", "a,b"])

    assert dir |> File.ls!() |> length() == 21
    assert <<"RIFF", _::binary>> = File.read!(Path.join(dir, "01.wav"))

    assert [%{"file" => "01.wav", "names" => ["Roxanne"]} | _] =
             Jason.decode!(File.read!(Path.join(dir, "questions.json")))

    assert Enum.any?(lines(), &(&1 =~ ~r/^total \d+ bytes/))

    SttEval.run(["--dir", dir, "--delay", "1200"])
    out = lines()

    assert Enum.any?(
             out,
             &(&1 =~ ~r/^02\.wav  batch WER 0\.0% names 1\/1  Where do I catch Ralts\?  realtime/)
           )

    assert "TOTAL realtime (delay 1200 ms) WER" <> _ =
             Enum.find(out, &String.starts_with?(&1, "TOTAL realtime"))

    # Same words from both fakes: a tie goes to realtime (at most and at least).
    assert "accuracy gate: stt_final :realtime" in out
  end

  test "dry run makes no calls, and a missing key stops before any" do
    Req.Test.stub(Maya.Mistral, fn _conn -> flunk("called Mistral") end)
    SttEval.run(["spike", "--dry-run"])
    assert Enum.any?(lines(), &(&1 =~ "session.update"))

    mistral = Application.fetch_env!(:maya, :mistral)
    Application.put_env(:maya, :mistral, Keyword.put(mistral, :api_key, nil))
    on_exit(fn -> Application.put_env(:maya, :mistral, mistral) end)
    assert_raise Mix.Error, "MISTRAL_API_KEY is not set", fn -> SttEval.run([]) end
  end
end
