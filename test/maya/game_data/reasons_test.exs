defmodule Maya.GameData.ReasonsTest do
  use ExUnit.Case, async: true

  alias Maya.GameData.Reasons

  @read &(&1 |> File.read!() |> Jason.decode!())
  @chart @read.("priv/data/type_matchups.json")
  @reasons @read.("priv/data/type_reasons.json")

  defp row(attacker, defender, multiplier, reason),
    do: %{
      "attacker" => attacker,
      "defender" => defender,
      "multiplier" => multiplier,
      "reason" => reason
    }

  test "the committed reasons are clean and cover every 0x pair" do
    assert Reasons.problems(@reasons, @chart) == []

    zeros = for %{"multiplier" => m} = r <- @chart, m == 0.0, do: {r["attacker"], r["defender"]}
    covered = for r <- @reasons, do: {r["attacker"], r["defender"]}
    assert zeros -- covered == []
  end

  test "Fire on Water at 2 is the wrong direction, so it does not match the chart" do
    assert Reasons.problems([row("fire", "water", 2.0, "Fire boils water.")], @chart) ==
             [{"fire on water", :not_in_chart}]
  end

  test "a neutral pair, a Fairy row and a banned word are each reported" do
    rows = [
      row("normal", "water", 1.0, "Nothing special."),
      row("steel", "fairy", 2.0, "Steel cuts fairies."),
      row("water", "fire", 2.0, "Water can beat Fire.")
    ]

    assert Reasons.problems(rows, @chart) == [
             {"normal on water", :not_in_chart},
             {"steel on fairy", :fairy},
             {"water on fire", :banned_word}
           ]
  end

  test "a pair twice and a line over 60 characters are reported" do
    long = String.duplicate("a", 61)
    rows = [row("water", "fire", 2.0, "Water puts out Fire."), row("water", "fire", 2.0, long)]

    assert Reasons.problems(rows, @chart) == [
             {"water on fire", :duplicate},
             {"water on fire", :too_long}
           ]
  end
end
