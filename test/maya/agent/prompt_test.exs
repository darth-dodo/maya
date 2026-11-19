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

  test "the honesty rule: the Answer schema, no unreturned tool claims, no tool talk (#118)" do
    prompt = Prompt.system(@progress)
    assert prompt =~ "used_tool_calls"

    assert prompt =~
             "Never claim a tool call, its result or a refusal unless that tool result was returned in this turn."

    assert prompt =~ "Never mention tools"
    assert prompt =~ "State a correction plainly"
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

  test "Prompt asks for log_event: one line per Team change kind and the honesty line" do
    prompt = Prompt.system(@progress)

    for kind <- ~w(deposited withdrawn set_lead set_team set_level),
        do: assert(prompt =~ ~s(kind "#{kind}"), "missing #{kind}")

    refute prompt =~ "level_up"
    assert prompt =~ "Never say a Team change happened unless log_event confirmed it."
  end

  # #183, phone 20:17: "Lotad level 14." became set_team with only Lotad, so Mudkip left the Team.
  test "set_team only for the whole Team; one member or a level is set_level" do
    prompt = Prompt.system(@progress)

    assert prompt =~
             ~s(Only when the player lists every member of their Team, call kind "set_team")

    assert prompt =~ ~s(One member with a level, like "Lotad level 14", is kind "set_level")
  end

  test "where to go comes only from search_guide's note" do
    prompt = Prompt.system(@progress)
    assert prompt =~ "call search_guide"
    assert prompt =~ "say only what its note says"
  end

  test "humor changes only through set_setting, and no Dial change without its confirm" do
    prompt = Prompt.system(@progress)
    assert prompt =~ "call set_setting"
    assert prompt =~ "Never say a Dial changed unless set_setting confirmed it in this turn."
    assert prompt =~ ~s("undo that" after a Dial change is set_setting again with the old value)
  end

  test "moves a Pokémon learns come only from move_learnset" do
    prompt = Prompt.system(@progress)
    assert prompt =~ "Always call move_learnset before you name a move a Pokémon learns."
    assert prompt =~ "Never name a move no tool returned in this turn."
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

  test "trainers and items come only from find_trainer and find_item" do
    prompt = Prompt.system(@progress)
    assert prompt =~ "call find_trainer"
    assert prompt =~ "call find_item"
    refute prompt =~ ~r/\b(beat|defeat)/i
  end
end
