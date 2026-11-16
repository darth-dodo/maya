defmodule Maya.AgentTest do
  use Maya.DataCase, async: true

  alias Maya.Agent
  alias Maya.Voice.Turn

  @roxanne "How do I earn Roxanne's badge?"
  @guest "agent-test"

  setup do
    :ok = Maya.GameData.import!()
    :ok
  end

  # Replies with `replies` in order, sending each decoded request body to the test.
  defp script(replies) do
    me = self()
    {:ok, agent} = Elixir.Agent.start_link(fn -> replies end)

    Req.Test.stub(Maya.OpenRouter, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      send(me, {:request, conn.request_path, Jason.decode!(body)})
      reply = Elixir.Agent.get_and_update(agent, fn [r | rest] -> {r, rest ++ [r]} end)
      Req.Test.json(conn, reply)
    end)
  end

  defp text(content),
    do: %{"choices" => [%{"message" => %{"role" => "assistant", "content" => content}}]}

  defp calls(calls) do
    tool_calls =
      for {id, name, args} <- calls,
          do: %{
            "id" => id,
            "type" => "function",
            "function" => %{"name" => name, "arguments" => args}
          }

    %{
      "choices" => [
        %{"message" => %{"role" => "assistant", "content" => nil, "tool_calls" => tool_calls}}
      ]
    }
  end

  defp tool_messages(%{"messages" => messages}),
    do: for(%{"role" => "tool"} = m <- messages, do: m)

  test "Roxanne: one gym_counter round trip, then the Answer names her ace and a counter" do
    answer =
      "Roxanne's ace is Nosepass at level 15. Lead with Mudkip, its water moves hit rock twice as hard. Mudkip would approve."

    script([calls([{"call_1", "gym_counter", ~s({"leader":"Roxanne"})}]), text(answer)])

    assert Agent.answer(@roxanne, [], guest_id: @guest) == {:ok, answer}

    assert_received {:request, "/v1/chat/completions", first}
    assert_received {:request, "/v1/chat/completions", second}

    for body <- [first, second] do
      assert body["model"] == "anthropic/claude-haiku-5.5"

      assert Enum.map(body["tools"], & &1["function"]["name"]) == [
               "search_guide",
               "gym_counter",
               "find_pokemon",
               "move_learnset",
               "log_event"
             ]

      refute Map.has_key?(body, "temperature")
    end

    assert [%{"role" => "system"}, %{"role" => "user", "content" => @roxanne}] = first["messages"]

    assert [%{"tool_call_id" => "call_1", "content" => content}] = tool_messages(second)

    assert %{
             "fact" => %{
               "ace" => %{"species" => "nosepass", "level" => 15},
               "suggested_lead" => "mudkip"
             }
           } =
             Jason.decode!(content)

    # The assistant's tool call is replayed before its result.
    assert %{"role" => "assistant", "tool_calls" => [%{"id" => "call_1"}]} =
             Enum.at(second["messages"], 2)
  end

  test "two calls in one round get one tool message each, in order" do
    script([
      calls([
        {"a", "find_pokemon", ~s({"name":"Ralts"})},
        {"b", "gym_counter", ~s({"leader":"Brawly"})}
      ]),
      text("Ralts is on Route 102. Further ahead, no spoilers.")
    ])

    assert {:ok, _} = Agent.answer("Where is Ralts and what about Brawly?", [], guest_id: @guest)
    assert_received {:request, _, _}
    assert_received {:request, _, second}

    assert [
             %{"tool_call_id" => "a", "content" => ralts},
             %{"tool_call_id" => "b", "content" => brawly}
           ] =
             tool_messages(second)

    assert ralts =~ "Route 102"
    assert %{"error" => "past_horizon", "hint" => _} = Jason.decode!(brawly)
  end

  test "malformed arguments are a tool error the model sees, not a crash" do
    script([calls([{"bad", "gym_counter", "{leader: Roxanne"}]), text("Not sure.")])

    assert Agent.answer(@roxanne, [], guest_id: @guest) == {:ok, "Not sure."}
    assert_received {:request, _, _}
    assert_received {:request, _, second}
    assert [%{"tool_call_id" => "bad", "content" => content}] = tool_messages(second)
    assert Jason.decode!(content) == %{"error" => "malformed_arguments"}
  end

  test "arguments that are JSON but not an object are malformed too" do
    script([calls([{"bad", "gym_counter", ~s(["Roxanne"])}]), text("Not sure.")])
    assert {:ok, "Not sure."} = Agent.answer(@roxanne, [], guest_id: @guest)
  end

  test "the loop stops after 4 requests" do
    script([calls([{"loop", "gym_counter", ~s({"leader":"Roxanne"})}])])

    assert Agent.answer(@roxanne, [], guest_id: @guest) == {:error, :round_cap}

    for _ <- 1..4, do: assert_received({:request, _, _})
    refute_received {:request, _, _}
  end

  test "an OpenRouter error is an agent error" do
    Req.Test.stub(Maya.OpenRouter, &Plug.Conn.send_resp(&1, 502, "bad gateway"))
    assert Agent.answer(@roxanne, [], guest_id: @guest) == {:error, {:http, 502}}
  end

  test "a reply with neither text nor tool calls is an agent error" do
    script([%{"error" => %{"message" => "provider down"}}])
    assert Agent.answer(@roxanne, [], guest_id: @guest) == {:error, :bad_reply}
  end

  test "the last 5 turns go between the system prompt and the Question" do
    script([text("Brawly is past the Next gym. Further ahead, no spoilers.")])
    turns = for n <- 1..7, do: %Turn{question: "q#{n}", answer: "a#{n}"}

    assert {:ok, _} = Agent.answer("What about Brawly?", turns, guest_id: @guest)
    assert_received {:request, _, %{"messages" => [%{"role" => "system"} | rest]}}

    expected =
      Enum.flat_map(
        3..7,
        &[
          %{"role" => "user", "content" => "q#{&1}"},
          %{"role" => "assistant", "content" => "a#{&1}"}
        ]
      ) ++
        [%{"role" => "user", "content" => "What about Brawly?"}]

    assert rest == expected
  end

  # PRODUCT.md "Done when (Sunday)": both Questions in one Conversation, the model stubbed.
  test "Sunday goal: Roxanne then Ralts in the same Conversation, each from a tool" do
    roxanne = "Roxanne's ace is Nosepass. Lead with Mudkip. Mudkip would approve."
    ralts = "Ralts lives in the grass on Route 102, about 4 percent of the time."

    script([
      calls([{"rox", "gym_counter", ~s({"leader":"Roxanne"})}]),
      text(roxanne),
      calls([{"ralts", "find_pokemon", ~s({"name":"Ralts"})}]),
      text(ralts)
    ])

    assert {:ok, ^roxanne} = Agent.answer(@roxanne, [], guest_id: @guest)

    turns = [%Turn{question: @roxanne, answer: roxanne}]
    assert {:ok, ^ralts} = Agent.answer("Where do I catch a Ralts?", turns, guest_id: @guest)

    assert_received {:request, _, _}
    assert_received {:request, _, rox_result}
    assert_received {:request, _, ralts_first}
    assert_received {:request, _, ralts_result}

    assert [%{"content" => fact}] = tool_messages(rox_result)

    assert %{"fact" => %{"ace" => %{"species" => "nosepass"}, "suggested_lead" => "mudkip"}} =
             Jason.decode!(fact)

    assert [%{"content" => places}] = tool_messages(ralts_result)
    assert %{"fact" => %{"places" => [%{"location" => "Route 102"} | _]}} = Jason.decode!(places)

    assert [
             %{"role" => "system"},
             %{"role" => "user", "content" => @roxanne},
             %{"role" => "assistant", "content" => ^roxanne},
             %{"role" => "user", "content" => "Where do I catch a Ralts?"}
           ] = ralts_first["messages"]
  end

  test "the model can be chosen per call" do
    script([text("Hi.")])
    assert {:ok, "Hi."} = Agent.answer("Hi", [], model: "openai/gpt-5.4-mini", guest_id: @guest)
    assert_received {:request, _, %{"model" => "openai/gpt-5.4-mini"}}
  end

  # Production #57: no progress row crashed in Horizon.next_gym(nil) via Prompt.system/1.
  test "without a guest there is no Progress: an error, not a crash, and no OpenRouter call" do
    Req.Test.stub(Maya.OpenRouter, fn _conn -> flunk("OpenRouter was called") end)

    assert Agent.answer("Hello", [], []) == {:error, :no_progress}
  end

  test "each guest's Answer uses their own Progress: a new guest is seeded" do
    Maya.GameData.progress("one-badge")
    Repo.query!("UPDATE progress SET badges = '{1}' WHERE guest_id = 'one-badge'")
    script([text("Hi.")])

    assert {:ok, _} = Agent.answer("Who is next?", [], guest_id: "one-badge")
    assert {:ok, _} = Agent.answer("Who is next?", [], guest_id: "brand-new")

    assert_received {:request, _, %{"messages" => [%{"content" => one_badge} | _]}}
    assert_received {:request, _, %{"messages" => [%{"content" => brand_new} | _]}}
    assert one_badge =~ "Next gym: Brawly"
    assert brand_new =~ "Next gym: Roxanne"
  end

  describe "Events" do
    @badge ~s({"kind":"badge_earned","details":{"leader":"Roxanne"}})

    test "\"I just earned Roxanne's badge\": logged, the Next gym is Brawly, and the next prompt says so" do
      guest = "events-agent"

      script([
        calls([{"log", "log_event", @badge}, {"brawly", "gym_counter", ~s({"leader":"Brawly"})}]),
        text("Stone Badge logged. Mudkip would approve.")
      ])

      assert {:ok, "Stone Badge logged. Mudkip would approve."} =
               Agent.answer("I just earned Roxanne's badge", [], guest_id: guest)

      assert_received {:request, _, _}
      assert_received {:request, _, second}

      assert [%{"tool_call_id" => "log", "content" => logged}, %{"content" => brawly}] =
               tool_messages(second)

      assert Jason.decode!(logged) == %{"confirm" => "Stone Badge logged. Mudkip would approve."}
      # The same turn already uses the new Progress: Brawly is now the Next gym.
      assert %{"fact" => %{"leader" => "Brawly"}} = Jason.decode!(brawly)

      assert Maya.Horizon.next_gym(Maya.GameData.progress(guest)).leader == "Brawly"

      assert {:ok, _} = Agent.answer("Who is next?", [], guest_id: guest)
      assert_received {:request, _, %{"messages" => [%{"content" => prompt} | _]}}
      assert prompt =~ "Next gym: Brawly (badge 2)"
    end

    test "\"No, undo that\" in the next turn reverts the last Event" do
      guest = "events-undo"
      script([calls([{"log", "log_event", @badge}]), text("Stone Badge logged.")])
      assert {:ok, _} = Agent.answer("I just earned Roxanne's badge", [], guest_id: guest)

      script([calls([{"undo", "log_event", ~s({"kind":"undo"})}]), text("Undone.")])
      assert {:ok, _} = Agent.answer("No, undo that", [], guest_id: guest)

      assert Maya.GameData.progress(guest).badges == []
      assert Maya.Horizon.next_gym(Maya.GameData.progress(guest)).leader == "Roxanne"
    end

    test "a later badge is refused politely and nothing changes" do
      guest = "events-later"

      script([
        calls([{"log", "log_event", ~s({"kind":"badge_earned","details":{"leader":"Wattson"}})}]),
        text("I can only log Roxanne's badge next.")
      ])

      assert {:ok, _} = Agent.answer("I earned Wattson's badge", [], guest_id: guest)
      assert_received {:request, _, _}
      assert_received {:request, _, second}
      assert [%{"content" => refused}] = tool_messages(second)
      assert Jason.decode!(refused) == %{"refused" => "I can only log Roxanne's badge next."}
      refute refused =~ "Mauville"
      assert Maya.GameData.progress(guest).badges == []
    end
  end
end
