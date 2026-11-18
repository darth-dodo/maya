defmodule Maya.Agent.AnswerTest do
  use ExUnit.Case, async: true

  alias Maya.Agent.Answer

  defp json(map), do: Jason.encode!(map)

  test "a valid Answer parses" do
    assert {:ok, %Answer{answer: "Not sure.", used_tool_calls: []}} =
             Answer.parse(json(%{answer: "Not sure.", used_tool_calls: []}))
  end

  test "plain text, missing fields, an empty answer or a wrong type is not the schema" do
    for bad <- [
          "Ralts is on Route 102.",
          json(%{used_tool_calls: []}),
          json(%{answer: "Hi."}),
          json(%{answer: "", used_tool_calls: []}),
          json(%{answer: "Hi.", used_tool_calls: "call_1"}),
          json(["Hi."]),
          nil
        ] do
      assert Answer.parse(bad) == {:error, :not_schema}, inspect(bad)
    end
  end

  defp answer(text, ids \\ []), do: %Answer{answer: text, used_tool_calls: ids}

  test "a cited id must be a tool call of this turn" do
    assert Answer.check(answer("Ralts is on Route 102.", ["call_9"]), %{"a" => "find_pokemon"}) ==
             {:error, {:unknown_call, "call_9"}}

    assert {:ok, _} =
             Answer.check(answer("Ralts is on Route 102.", ["a"]), %{"a" => "find_pokemon"})
  end

  for word <- Answer.claim_words() do
    @word word
    test "the claim #{inspect(word)} needs a log_event or set_setting that ran this turn" do
      # The Team noun makes a generic word such as "updated" a claim too.
      text = "Sure, your Team #{@word} for you."
      assert {:error, {:unbacked_claim, _}} = Answer.check(answer(text), %{})
      # A read tool does not back a write claim.
      assert {:error, {:unbacked_claim, _}} =
               Answer.check(answer(text, ["f"]), %{"f" => "find_pokemon"})

      assert {:ok, _} = Answer.check(answer(text, ["l"]), %{"l" => "log_event"})
      assert {:ok, _} = Answer.check(answer(text), %{"s" => "set_setting"})
    end
  end

  # #183, phone 2026-11-18: set_team ran but the model cited nothing; the change really happened.
  test "a write claim passes when a write ran this turn, even if not cited" do
    text = "Team set: Mudkip level 16, Taillow level 12."
    assert {:ok, ^text} = Answer.check(answer(text), %{"c1" => "log_event"})
  end

  test "an ordinary got it with no write passes" do
    assert {:ok, _} = Answer.check(answer("Got it, Brawly uses Fighting types."), %{})
  end

  test "a cited id that did not run is rejected even when a write ran" do
    assert Answer.check(answer("Team set.", ["x"]), %{"l" => "log_event"}) ==
             {:error, {:unknown_call, "x"}}
  end

  test "generic change words count only next to a Progress noun" do
    assert {:ok, _} = Answer.check(answer("Noted, Brawly is tough."), %{})
    assert {:ok, _} = Answer.check(answer("The guide was updated for Emerald."), %{})

    assert {:error, {:unbacked_claim, "updated"}} =
             Answer.check(answer("Your Team is updated."), %{})

    assert {:ok, _} = Answer.check(answer("Noted, Mudkip learns it at level 10."), %{})

    assert {:error, {:unbacked_claim, "saved"}} =
             Answer.check(answer("Saved, Mudkip is on your Team."), %{})
  end

  test "tool talk passes when the Question asks about tools" do
    text = "My tools look up Pokémon and gyms."
    assert {:error, {:tool_talk, "tools"}} = Answer.check(answer(text), %{})
    assert {:ok, ^text} = Answer.check(answer(text), %{}, "What tools do you have?")
  end

  test "talk about tools is rejected even with a write call" do
    text = "I never actually called the tool for Slateport."

    assert Answer.check(answer(text, ["l"]), %{"l" => "log_event"}) ==
             {:error, {:tool_talk, "tool"}}
  end

  test "chat and Facts with no claim pass, and words match on boundaries" do
    assert {:ok, "Ralts lives on Route 102."} =
             Answer.check(answer("Ralts lives on Route 102."), %{})

    refute Answer.said?("That move is denoted Tackle.", "noted")
  end

  test "spoken keeps at most 3 sentences and leaves Mt. inside one" do
    assert Answer.spoken("One. Two! Three? Four. Five.") == "One. Two! Three?"
    assert Answer.spoken("Head to Mt. Chimney. Then rest.") == "Head to Mt. Chimney. Then rest."
    assert Answer.spoken("  Not sure.  ") == "Not sure."
  end

  test "a claim in a trimmed fourth sentence is never said, so it passes" do
    assert {:ok, "A. B. C."} = Answer.check(answer("A. B. C. Ralts logged."), %{})
  end
end
