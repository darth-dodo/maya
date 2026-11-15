defmodule Mix.Tasks.Maya.SttEval do
  @shortdoc "Realtime STT spike, eval clips and batch vs realtime accuracy (needs the real key)"
  @moduledoc """
  The realtime transcription checks of ADR-009. Each needs `MISTRAL_API_KEY` (read in
  config/runtime.exs) and an imported database, costs well under a cent, and is never run in
  CI. `--dry-run` prints what it would do without calling Mistral.

      mix maya.stt_eval spike              # one Question through realtime: events, end to done ms
      mix maya.stt_eval fixtures --voices ID1,ID2,ID3
      mix maya.stt_eval [--delay 480]      # WER and name accuracy, batch vs realtime

  `spike` speaks "How do I earn Roxanne's badge?" with Voxtral TTS, streams it to the realtime
  endpoint in 100 ms chunks paced in real time and prints the events, the transcript and the
  time from `input_audio.end` to `transcription.done`. A 401, 403 or 404 means stop (#75).

  `fixtures` writes `test/fixtures/stt_eval/01.wav` to `20.wav` (16 kHz mono 16-bit, at most
  5 s, light noise added) and `questions.json` from the design.md script, rotating through the
  given TTS voice ids (`GET /v1/audio/voices`; default: Maya's voice). TTS clips are cleaner
  than a voice in a room, so the eval is optimistic (Abhishek, #75).

  The eval transcribes every clip with batch and with realtime, both with the bias terms of
  the seed Progress and `Vocabulary.correct`, and prints per clip and total numbers and which
  source the accuracy gate picks for `:stt_final`.
  """
  use Mix.Task

  alias Maya.Voice.{Realtime, STT, TTS, Vocabulary, Wav, WER}

  @requirements ["app.start"]
  @dir "test/fixtures/stt_eval"
  # Its own guest, so the eval never touches a player's Progress (ADR-008).
  @guest "stt-eval"
  @rate 16_000
  # 100 ms of 16-bit samples, the Mistral sample's chunk size.
  @chunk div(@rate, 10) * 2
  # Peak to peak white noise, about -56 dBFS: "light background noise" (#75).
  @noise 0.003

  # design.md, Accuracy evaluation: the script and the names each Question must get right.
  @questions [
    {"How do I earn Roxanne's badge?", ["Roxanne"]},
    {"Where do I catch Ralts?", ["Ralts"]},
    {"Is Zigzagoon on Route 101?", ["Zigzagoon"]},
    {"What is Torchic weak to?", ["Torchic"]},
    {"When does Mudkip evolve?", ["Mudkip"]},
    {"What should I lead with against Brawly?", ["Brawly"]},
    {"How far is Dewford Town?", ["Dewford Town"]},
    {"Can I catch Wingull on Route 104?", ["Wingull"]},
    {"What type is Nosepass?", ["Nosepass"]},
    {"How do I get to Rustboro City?", ["Rustboro City"]},
    {"Is Geodude good against Roxanne?", ["Geodude", "Roxanne"]},
    {"Where can I find Shroomish?", ["Shroomish"]},
    {"What level does Marshtomp evolve?", ["Marshtomp"]},
    {"What does Wurmple evolve into?", ["Wurmple"]},
    {"Where do I catch Taillow in Petalburg Woods?", ["Taillow", "Petalburg Woods"]},
    {"Who is the gym leader in Dewford Town?", ["Dewford Town"]},
    {"Is Lotad a Water type?", ["Lotad"]},
    {"How do I get from Littleroot Town to Oldale Town?", ["Littleroot Town", "Oldale Town"]},
    {"What moves does Makuhita learn?", ["Makuhita"]},
    {"How do I get past Petalburg Woods?", ["Petalburg Woods"]}
  ]

  @impl true
  def run(args) do
    {opts, rest} =
      OptionParser.parse!(args,
        strict: [dry_run: :boolean, delay: :integer, voices: :string, dir: :string]
      )

    if opts[:delay], do: put_voice(:stt_realtime_delay_ms, opts[:delay])

    cond do
      opts[:dry_run] ->
        dry_run(rest, opts)

      Application.fetch_env!(:maya, :mistral)[:api_key] in [nil, ""] ->
        Mix.raise("MISTRAL_API_KEY is not set")

      true ->
        command(rest, opts, opts[:dir] || @dir)
    end
  end

  defp command(["spike"], _opts, _dir), do: spike()
  defp command(["fixtures"], opts, dir), do: fixtures(opts, dir)
  defp command([], _opts, dir), do: eval(dir)

  defp command(_rest, _opts, _dir),
    do: Mix.raise("usage: mix maya.stt_eval [spike | fixtures] [--delay MS] [--dry-run]")

  defp dry_run(rest, opts) do
    voice = Application.fetch_env!(:maya, :voice)

    info("dry run, no Mistral calls: #{Enum.join(rest, " ")}")
    info("realtime #{voice[:stt_realtime_url]}?model=#{voice[:stt_realtime_model]}")

    info(
      "delay #{voice[:stt_realtime_delay_ms]} ms, voices #{opts[:voices] || voice[:tts_voice]}"
    )

    info("#{length(@questions)} Questions, clips in #{opts[:dir] || @dir}")

    info(
      "session.update: #{Jason.encode!(Realtime.session_update(terms()))}"
      |> String.slice(0, 300)
    )
  end

  defp spike do
    pcm =
      speak("How do I earn Roxanne's badge?", Application.fetch_env!(:maya, :voice)[:tts_voice])

    info("spoken: #{byte_size(pcm)} bytes, #{div(byte_size(pcm) * 1000, @rate * 2)} ms of audio")

    case realtime(pcm) do
      {:ok, text, deltas, ms} ->
        info("events: session.created, #{deltas} transcription.text.delta, transcription.done")
        info("transcript: #{text}")
        info("input_audio.end to transcription.done: #{ms} ms")

      {:error, {:http, status}} when status in [401, 403, 404] ->
        Mix.raise("realtime refused with HTTP #{status}: stop and report on #75")

      {:error, reason} ->
        Mix.raise("realtime failed: #{inspect(reason)}")
    end
  end

  defp fixtures(opts, dir) do
    voice = Application.fetch_env!(:maya, :voice)[:tts_voice]
    voices = if opts[:voices], do: String.split(opts[:voices], ","), else: [voice]
    File.mkdir_p!(dir)
    :rand.seed(:exsss, {7, 5, 75})

    index =
      for {{text, names}, i} <- Enum.with_index(@questions, 1) do
        file = String.pad_leading("#{i}", 2, "0") <> ".wav"
        pcm = speak(text, Enum.at(voices, rem(i - 1, length(voices))))
        File.write!(Path.join(dir, file), Wav.wrap(pcm, @rate))
        info("#{file} #{div(byte_size(pcm) * 1000, @rate * 2)} ms  #{text}")
        %{file: file, text: text, names: names}
      end

    File.write!(Path.join(dir, "questions.json"), Jason.encode!(index, pretty: true))
    total = dir |> File.ls!() |> Enum.map(&File.stat!(Path.join(dir, &1)).size) |> Enum.sum()
    info("total #{total} bytes (must be under 3.5 MB)")
  end

  defp eval(dir) do
    terms = terms()
    clips = Path.join(dir, "questions.json") |> File.read!() |> Jason.decode!()

    rows =
      for %{"file" => file, "text" => ref, "names" => names} <- clips do
        <<_header::binary-44, pcm::binary>> = File.read!(Path.join(dir, file))

        batch =
          case STT.transcribe(Wav.wrap(pcm, @rate), file, terms) do
            {:ok, text} -> Vocabulary.correct(text, terms)
            {:error, reason} -> Mix.raise("batch failed on #{file}: #{inspect(reason)}")
          end

        live =
          case realtime(pcm) do
            {:ok, text, _deltas, _ms} -> Vocabulary.correct(text, terms)
            {:error, reason} -> Mix.raise("realtime failed on #{file}: #{inspect(reason)}")
          end

        row = %{ref: ref, names: names, batch: batch, realtime: live}
        info("#{file}  batch #{score(row, :batch)}  realtime #{score(row, :realtime)}")
        row
      end

    {b_wer, b_names} = totals(rows, :batch)
    {r_wer, r_names} = totals(rows, :realtime)
    delay = Application.fetch_env!(:maya, :voice)[:stt_realtime_delay_ms]
    info("TOTAL batch WER #{pct(b_wer)} names #{pct(b_names)}")
    info("TOTAL realtime (delay #{delay} ms) WER #{pct(r_wer)} names #{pct(r_names)}")
    final = if r_wer <= b_wer and r_names >= b_names, do: :realtime, else: :batch
    info("accuracy gate: stt_final #{inspect(final)}")
  end

  defp score(row, source) do
    text = Map.fetch!(row, source)

    "WER #{pct(WER.wer(row.ref, text))} names #{WER.names_found(row.names, text)}/#{length(row.names)}  #{text}"
  end

  defp totals(rows, source) do
    {edits, words} =
      rows
      |> Enum.map(&WER.edits(&1.ref, Map.fetch!(&1, source)))
      |> Enum.reduce({0, 0}, fn {e, w}, {es, ws} -> {es + e, ws + w} end)

    found = Enum.sum(Enum.map(rows, &WER.names_found(&1.names, Map.fetch!(&1, source))))
    {edits / words, found / Enum.sum(Enum.map(rows, &length(&1.names)))}
  end

  # Streams 16 kHz pcm_s16le paced in real time, as the Mistral sample does for latency.
  defp realtime(pcm) do
    ref = make_ref()
    {relay, _mon} = Realtime.start(self(), ref, terms())

    for <<chunk::binary-size(@chunk) <- pcm>> do
      send(relay, {:audio, Base.encode64(chunk)})
      Process.sleep(100)
    end

    tail =
      binary_part(pcm, byte_size(pcm) - rem(byte_size(pcm), @chunk), rem(byte_size(pcm), @chunk))

    if tail != "", do: send(relay, {:audio, Base.encode64(tail)})
    send(relay, :end)
    ended = System.monotonic_time(:millisecond)
    await(ref, ended, 0)
  end

  defp await(ref, ended, deltas) do
    receive do
      {:partial, ^ref, _text} ->
        await(ref, ended, deltas + 1)

      {:realtime_done, ^ref, text} ->
        {:ok, text, deltas, System.monotonic_time(:millisecond) - ended}

      {:realtime_failed, ^ref, reason} ->
        {:error, reason}
    after
      10_000 -> {:error, :no_done_in_10_s}
    end
  end

  # Voxtral TTS (float32 LE at 24 kHz) to 16 kHz pcm_s16le, at most 5 s, with light noise.
  defp speak(text, voice) do
    put_voice(:tts_voice, voice)
    me = self()
    :ok = TTS.stream(text, &send(me, {:tts, &1}))

    collect(<<>>)
    |> floats()
    |> resample(24_000, @rate)
    |> Enum.take(5 * @rate)
    |> Enum.map_join(
      &<<round(clamp(&1 + (:rand.uniform() - 0.5) * @noise) * 32_767)::little-signed-16>>
    )
  end

  defp collect(acc) do
    receive do
      {:tts, chunk} -> collect(acc <> chunk)
    after
      0 -> acc
    end
  end

  defp floats(bin), do: for(<<f::little-float-32 <- bin>>, do: f)

  # Linear interpolation; Voxtral TTS is 24 kHz and STT wants 16 kHz.
  defp resample(samples, from, to) do
    tuple = List.to_tuple(samples)
    last = tuple_size(tuple) - 1

    for i <- 0..max(div(last * to, from), 0)//1, last >= 0 do
      pos = i * from / to
      j = trunc(pos)
      a = elem(tuple, min(j, last))
      b = elem(tuple, min(j + 1, last))
      a + (b - a) * (pos - j)
    end
  end

  defp clamp(x), do: x |> max(-1.0) |> min(1.0)

  defp terms, do: Vocabulary.bias_terms(Maya.GameData.progress(@guest))

  defp put_voice(key, value) do
    voice = Application.fetch_env!(:maya, :voice)
    Application.put_env(:maya, :voice, Keyword.put(voice, key, value))
  end

  defp pct(x), do: "#{Float.round(x * 100, 1)}%"
  defp info(text), do: Mix.shell().info(text)
end
