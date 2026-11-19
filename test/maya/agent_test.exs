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

  # A structured Answer citing `ids`, or raw `content` when it is not a string Answer.
  defp text(answer, ids \\ []),
    do: raw(Jason.encode!(%{answer: answer, used_tool_calls: ids}))

  defp raw(content),
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

    script([
      calls([{"call_1", "gym_counter", ~s({"leader":"Roxanne"})}]),
      text(answer, ["call_1"])
    ])

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
               "find_trainer",
               "find_item",
               "team_check",
               "log_event",
               "set_setting"
             ]

      refute Map.has_key?(body, "temperature")
      assert body["provider"] == %{"require_parameters" => true}

      assert %{"type" => "json_schema", "json_schema" => %{"name" => "answer", "strict" => true}} =
               body["response_format"]

      assert body["response_format"]["json_schema"]["schema"]["required"] == [
               "answer",
               "used_tool_calls"
             ]
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
      text(roxanne, ["rox"]),
      calls([{"ralts", "find_pokemon", ~s({"name":"Ralts"})}]),
      text(ralts, ["ralts"])
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
        text("Stone Badge logged. Mudkip would approve.", ["log"])
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
      script([calls([{"log", "log_event", @badge}]), text("Stone Badge logged.", ["log"])])
      assert {:ok, _} = Agent.answer("I just earned Roxanne's badge", [], guest_id: guest)

      script([calls([{"undo", "log_event", ~s({"kind":"undo"})}]), text("Undone.", ["undo"])])
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

    test "\"My Team is Mudkip 16, Taillow 12\": one set_team call, and the next prompt shows it" do
      guest = "events-set-team"

      team =
        ~s({"kind":"set_team","details":{"team":[{"species":"Mudkip","level":16},{"species":"Taillow","level":12}]}})

      script([calls([{"team", "log_event", team}]), text("Team set.", ["team"])])

      assert {:ok, _} = Agent.answer("My Team is Mudkip 16, Taillow 12", [], guest_id: guest)
      assert_received {:request, _, _}
      assert_received {:request, _, second}
      assert [%{"content" => logged}] = tool_messages(second)
      assert %{"confirm" => "Team set: " <> _} = Jason.decode!(logged)

      assert {:ok, _} = Agent.answer("Who leads?", [], guest_id: guest)
      assert_received {:request, _, %{"messages" => [%{"content" => prompt} | _]}}
      assert prompt =~ "Team: mudkip level 16, taillow level 12"
    end

    test "gym_counter after a new lead lists the Team with Wingull first" do
      guest = "events-set-lead"
      progress = Maya.GameData.progress(guest)
      {:ok, _, _} = Maya.Events.log(progress, "caught", %{"species" => "wingull", "level" => 8})

      script([
        calls([
          {"lead", "log_event", ~s({"kind":"set_lead","details":{"species":"Wingull"}})},
          {"roxanne", "gym_counter", ~s({"leader":"Roxanne"})}
        ]),
        text("Wingull leads the Team now.", ["lead"])
      ])

      assert {:ok, _} = Agent.answer("Make Wingull my lead", [], guest_id: guest)
      assert_received {:request, _, _}
      assert_received {:request, _, second}
      assert [%{"content" => led}, %{"content" => roxanne}] = tool_messages(second)
      assert Jason.decode!(led) == %{"confirm" => "Wingull leads the Team now."}

      assert %{"fact" => %{"team" => [%{"species" => "wingull"}, %{"species" => "mudkip"}]}} =
               Jason.decode!(roxanne)
    end
  end

  describe "set_setting" do
    test "\"Maya, humor 60\": confirmed, stored, and the rest of the turn's prompt says humor 60" do
      guest = "humor-agent"

      script([
        calls([{"humor", "set_setting", ~s({"name":"humor","value":60})}]),
        text("Humor set to 60 percent.")
      ])

      assert {:ok, "Humor set to 60 percent."} =
               Agent.answer("Maya, humor 60", [], guest_id: guest)

      assert_received {:request, _, %{"messages" => [%{"content" => before} | _]}}
      assert_received {:request, _, %{"messages" => [%{"content" => prompt} | _]} = second}
      assert before =~ "humor 75"
      assert prompt =~ "humor 60"
      assert [%{"content" => confirm}] = tool_messages(second)
      assert Jason.decode!(confirm) == %{"confirm" => "Humor set to 60 percent."}
      refute_received {:request, _, _}
      assert Maya.GameData.progress(guest).humor == 60
    end

    test "spoilers 50 is refused out loud and nothing changes" do
      guest = "spoilers-agent"

      script([
        calls([{"dial", "set_setting", ~s({"name":"spoilers","value":50})}]),
        text("Spoilers stay at 0, no spoilers from me.")
      ])

      assert {:ok, "Spoilers stay at 0" <> _} =
               Agent.answer("Maya, spoilers 50", [], guest_id: guest)

      assert_received {:request, _, _}
      assert_received {:request, _, second}
      assert [%{"content" => refused}] = tool_messages(second)
      assert %{"refused" => _} = Jason.decode!(refused)
      assert Maya.GameData.progress(guest).humor == 75
    end
  end

  describe "honesty check (#118)" do
    @fallback "Not sure I got that right, ask me again?"
    @ralts "Can you add Ralts to my team?"

    # The last user message of a request: the corrective one names the reason.
    defp last_user(%{"messages" => messages}),
      do: messages |> Enum.filter(&(&1["role"] == "user")) |> List.last() |> Map.get("content")

    test "a claimed refusal with no tool call gets one corrective request, then the corrected Answer" do
      script([
        text("I refused Ralts because your team is full."),
        text("Not sure, tell me if you caught Ralts.")
      ])

      assert Agent.answer(@ralts, [], guest_id: @guest) ==
               {:ok, "Not sure, tell me if you caught Ralts."}

      assert_received {:request, _, _}
      assert_received {:request, _, corrective}
      assert last_user(corrective) =~ ~s("refused")
      assert last_user(corrective) =~ "no log_event"
      refute_received {:request, _, _}
    end

    test "a claimed refusal rejected twice is the fallback line, with no third request" do
      script([text("I refused Ralts because your team is full.")])

      assert Agent.answer(@ralts, [], guest_id: @guest) == {:ok, @fallback}
      for _ <- 1..2, do: assert_received({:request, _, _})
      refute_received {:request, _, _}
    end

    test "citing call_9, which never ran, is ignored with no corrective request" do
      script([text("Ralts is on Route 102.", ["call_9"])])

      assert Agent.answer("Where is Ralts?", [], guest_id: @guest) ==
               {:ok, "Ralts is on Route 102."}

      assert_received {:request, _, _}
      refute_received {:request, _, _}
    end

    test "a confirm backed by its log_event call passes with no corrective request" do
      caught = ~s({"kind":"caught","details":{"species":"Ralts","level":4}})

      script([
        calls([{"catch", "log_event", caught}]),
        text("Ralts level 4 logged on the Team.", ["catch"])
      ])

      assert {:ok, "Ralts level 4 logged on the Team."} =
               Agent.answer("I caught a Ralts at level 4", [], guest_id: "honesty-catch")

      for _ <- 1..2, do: assert_received({:request, _, _})
      refute_received {:request, _, _}
    end

    # Phone, 2026-11-18: "Slateport was logged" with no log_event, then talk about the tool.
    test "Slateport: a location claimed without log_event, then tool talk, ends in the fallback" do
      script([
        text("Slateport is logged as your location."),
        text("I need to correct myself, I never actually called the tool for Slateport.")
      ])

      assert Agent.answer("I'm in Slateport", [], guest_id: @guest) == {:ok, @fallback}
    end

    test "plain text, missing answer or an empty answer is rejected like any bad Answer" do
      for bad <- [
            "Ralts is on Route 102.",
            ~s({"used_tool_calls":[]}),
            ~s({"answer":"","used_tool_calls":[]})
          ] do
        script([raw(bad)])
        assert Agent.answer("Where is Ralts?", [], guest_id: @guest) == {:ok, @fallback}
      end
    end

    test "a long Answer is trimmed to 3 spoken sentences, with no extra request" do
      script([text("One. Two at Mt. Pyre? Three! Four. Five.")])
      assert Agent.answer("Hi", [], guest_id: @guest) == {:ok, "One. Two at Mt. Pyre? Three!"}
      assert_received {:request, _, _}
      refute_received {:request, _, _}
    end

    # #183: a write that ran is never silent, so its confirm line replaces the fallback.
    @mudkip ~s({"kind":"set_level","details":{"species":"Mudkip","level":14}})

    test "a write that ran, then an Answer rejected twice, says the confirm line" do
      script([
        calls([{"lvl", "log_event", @mudkip}]),
        text("I need to check the tool."),
        text("I need to check the tool.")
      ])

      assert {:ok, line} = Agent.answer("Mudkip level 14.", [], guest_id: "honesty-write")
      assert line =~ "Mudkip"
      refute line == @fallback
    end

    test "a refused write, then an Answer rejected twice, says the refused line" do
      script([
        calls([{"team", "log_event", ~s({"kind":"set_team","details":{}})}]),
        text("I need to check the tool."),
        text("I need to check the tool.")
      ])

      assert Agent.answer("My Team is nobody", [], guest_id: "honesty-refused") ==
               {:ok, "A Team holds 1 to 6 Pokémon."}
    end

    # #192: a refused set_setting backs no "Humor set to 100.", so the refused line is said.
    test "a refused set_setting, then a claimed change rejected twice, says the refused line" do
      script([
        calls([{"humor", "set_setting", ~s({"name":"humor","value":150})}]),
        text("Humor set to 100."),
        text("Humor set to 100.")
      ])

      assert Agent.answer("Maya, humor 150", [], guest_id: "honesty-humor") ==
               {:ok, "Humor goes from 0 to 100 percent, so it stays as it is."}

      assert Maya.GameData.progress("honesty-humor").humor == 75
    end

    test "a confirmed set_setting backs \"Humor set to 100.\" with no corrective request" do
      script([
        calls([{"humor", "set_setting", ~s({"name":"humor","value":100})}]),
        text("Humor set to 100.")
      ])

      assert Agent.answer("Maya, humor 100", [], guest_id: "honesty-humor-ok") ==
               {:ok, "Humor set to 100."}

      assert_received {:request, _, _}
      assert_received {:request, _, _}
      refute_received {:request, _, _}
    end

    # #183, phone 20:17 "Lost my train of thought": a Team update hit the round cap after its write.
    test "a write that ran, then the round cap, says the confirm line, not an error" do
      loop = calls([{"loop", "gym_counter", ~s({"leader":"Roxanne"})}])
      script([calls([{"lvl", "log_event", @mudkip}]), loop, loop, loop])

      assert {:ok, line} =
               Agent.answer("Update my team. Mudkip level 14.", [], guest_id: "honesty-cap")

      assert line =~ "Mudkip"
    end

    test "a write that ran, then an OpenRouter error, says the confirm line" do
      me = self()
      {:ok, n} = Elixir.Agent.start_link(fn -> 0 end)

      Req.Test.stub(Maya.OpenRouter, fn conn ->
        send(me, :request)

        case Elixir.Agent.get_and_update(n, &{&1, &1 + 1}) do
          0 -> Req.Test.json(conn, calls([{"lvl", "log_event", @mudkip}]))
          _ -> Plug.Conn.send_resp(conn, 502, "bad gateway")
        end
      end)

      assert {:ok, line} = Agent.answer("Mudkip level 14.", [], guest_id: "honesty-502")
      assert line =~ "Mudkip"
    end

    test "a Question about tools may get an Answer that names tools" do
      script([text("My tools look up Pokémon, gyms and the guide.")])

      assert Agent.answer("What tools do you have?", [], guest_id: @guest) ==
               {:ok, "My tools look up Pokémon, gyms and the guide."}
    end

    test "a corrective request with no request left is the fallback, not a round cap error" do
      loop = calls([{"loop", "gym_counter", ~s({"leader":"Roxanne"})}])
      script([loop, loop, loop, text("I refused that."), loop])

      assert Agent.answer(@roxanne, [], guest_id: @guest) == {:ok, @fallback}
      for _ <- 1..4, do: assert_received({:request, _, _})
      refute_received {:request, _, _}
    end
  end
end
