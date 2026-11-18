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
    test "the claim #{inspect(word)} needs a cited log_event or set_setting" do
      text = "Sure, #{@word} for you."
      assert {:error, {:unbacked_claim, _}} = Answer.check(answer(text), %{})
      # A read tool does not back a write claim.
      assert {:error, {:unbacked_claim, _}} =
               Answer.check(answer(text, ["f"]), %{"f" => "find_pokemon"})

      assert {:ok, _} = Answer.check(answer(text, ["l"]), %{"l" => "log_event"})
      assert {:ok, _} = Answer.check(answer(text, ["s"]), %{"s" => "set_setting"})
    end
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
