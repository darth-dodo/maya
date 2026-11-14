defmodule Maya.Agent.PromptTest do
  use ExUnit.Case, async: true

  alias Maya.Agent.Prompt

  @progress %{
    badges: [],
    team: [%{"species" => "mudkip", "level" => 5}],
    location: "Littleroot Town",
    humor: 75
  }

  test "the system prompt carries the Answer rules, the Dials and Progress" do
    prompt = Prompt.system(@progress)

    for text <- [
          "Roxanne",
          "mudkip level 5",
          "humor 75",
          "honesty 90",
          "sass 40",
          "spoilers 0",
          "Mudkip hype 100",
          "Further ahead, no spoilers",
          "Not sure",
          "Mudkip would approve.",
          "2 to 3",
          "tool results"
        ],
        do: assert(prompt =~ text, "missing #{inspect(text)}")
  end

  test "the system prompt uses inclusive language" do
    refute Prompt.system(@progress) =~ ~r/\b(beat|defeat)/i
  end

  test "humor follows Progress and badges are counted" do
    prompt = Prompt.system(%{@progress | humor: 20, badges: [1]})
    assert prompt =~ "humor 20"
    assert prompt =~ "Brawly"
    assert prompt =~ "Badges earned: 1"
  end

  test "with all 8 badges there is no Next gym" do
    assert Prompt.system(%{@progress | badges: Enum.to_list(1..8)}) =~ "Next gym: none"
  end
end
