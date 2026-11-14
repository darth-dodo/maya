defmodule Maya.Voice.Latency do
  @moduledoc "Pure p50 and p95 per voice stage over stored turns (nearest rank)."

  @stages [:mic_release_ms, :stt_ms, :agent_ms, :tts_first_byte_ms, :playback_start_ms]

  def stages, do: @stages

  @spec summary([map()]) :: keyword()
  def summary(rows) do
    for stage <- @stages do
      values = rows |> Enum.map(&Map.get(&1, stage)) |> Enum.reject(&is_nil/1) |> Enum.sort()
      {stage, %{count: length(values), p50: rank(values, 50), p95: rank(values, 95)}}
    end
  end

  @spec format(keyword()) :: String.t()
  def format(summary) do
    Enum.map_join(summary, "\n", fn
      {stage, %{count: 0}} -> pad(stage) <> "missing"
      {stage, s} -> pad(stage) <> "n=#{s.count} p50=#{s.p50} p95=#{s.p95}"
    end)
  end

  defp pad(stage), do: String.pad_trailing(to_string(stage), 20)

  defp rank([], _p), do: nil
  defp rank(sorted, p), do: Enum.at(sorted, ceil(p / 100 * length(sorted)) - 1)
end
