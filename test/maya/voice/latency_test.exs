defmodule Maya.Voice.LatencyTest do
  use ExUnit.Case, async: true

  alias Maya.Voice.Latency

  test "p50 and p95 by nearest rank per stage, missing stages are nil" do
    rows = for ms <- [500, 100, 400, 200, 300], do: %{stt_ms: ms, tts_first_byte_ms: nil}

    summary = Latency.summary(rows)

    assert summary[:stt_ms] == %{count: 5, p50: 300, p95: 500}
    assert summary[:tts_first_byte_ms] == %{count: 0, p50: nil, p95: nil}
    assert Keyword.keys(summary) == Latency.stages()
  end

  test "one value is its own p50 and p95" do
    assert Latency.summary([%{playback_start_ms: 2400}])[:playback_start_ms] ==
             %{count: 1, p50: 2400, p95: 2400}
  end

  test "format prints missing for an empty stage" do
    text = [%{stt_ms: 100}] |> Latency.summary() |> Latency.format()

    assert text =~ ~r/stt_ms\s+n=1\s+p50=100\s+p95=100/
    assert text =~ ~r/mic_release_ms\s+missing/
  end
end
