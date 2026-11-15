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

  test "progress the player reports becomes a log_event call, and no or undo that undoes it" do
    prompt = Prompt.system(@progress)
    assert prompt =~ "log_event"
    assert prompt =~ ~s(kind "undo")
    assert prompt =~ "confirm"
    assert prompt =~ "refused"
  end

  test "moves a Pokémon learns come only from move_learnset" do
    prompt = Prompt.system(@progress)
    assert prompt =~ "Always call move_learnset before you name a move a Pokémon learns."
    assert prompt =~ "Never name a move move_learnset did not return in this turn."
  end

  test "the prompt shows the Progress after an Event" do
    prompt =
      Prompt.system(%{@progress | badges: [1], team: [%{"species" => "mudkip", "level" => 13}]})

    assert prompt =~ "Next gym: Brawly (badge 2)"
    assert prompt =~ "mudkip level 13"
  end

  test "with all 8 badges there is no Next gym" do
    assert Prompt.system(%{@progress | badges: Enum.to_list(1..8)}) =~ "Next gym: none"
  end
end
