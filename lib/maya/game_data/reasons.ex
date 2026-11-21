defmodule Maya.GameData.Reasons do
  @moduledoc """
  The type reasons checker: pure, on the decoded `type_reasons.json` and `type_matchups.json`.
  A reason must be for a chart pair with the same multiplier, never Fairy (not in Emerald),
  once per pair, one line of at most 60 characters, never "beat" or "defeat" (fail closed).
  """

  @max 60

  @doc "Every problem in the reasons as `{\"water on fire\", problem}`, `[]` when they are clean."
  def problems(reasons, chart) do
    chart = Map.new(chart, &{{&1["attacker"], &1["defender"]}, &1["multiplier"]})

    duplicates =
      for {{a, d}, [_, _ | _]} <- Enum.group_by(reasons, &{&1["attacker"], &1["defender"]}),
          do: {"#{a} on #{d}", :duplicate}

    duplicates ++ for(r <- reasons, problem = problem(r, chart), do: {pair(r), problem})
  end

  defp problem(%{"attacker" => a, "defender" => d, "multiplier" => m, "reason" => text}, chart) do
    cond do
      "fairy" in [a, d] -> :fairy
      not is_number(m) or chart[{a, d}] != m * 1.0 -> :not_in_chart
      not is_binary(text) or text =~ "\n" or String.length(text) > @max -> :too_long
      text =~ ~r/\b(beat|defeat)/i -> :banned_word
      true -> nil
    end
  end

  defp problem(_row, _chart), do: :not_in_chart

  defp pair(r), do: "#{r["attacker"]} on #{r["defender"]}"
end
