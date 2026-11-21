defmodule Maya.Agent.ToolsTest do
  use Maya.DataCase, async: true

  alias Maya.Agent.Tools
  alias Maya.GameData

  setup do
    :ok = GameData.import!()
    %{progress: GameData.progress("tools-test")}
  end

  test "every tool has an OpenAI-style function definition" do
    names =
      for %{type: "function", function: %{name: n, parameters: %{type: "object"}}} <-
            Tools.definitions(),
          do: n

    assert Enum.sort(names) == [
             "find_item",
             "find_pokemon",
             "find_trainer",
             "gym_counter",
             "log_event",
             "move_learnset",
             "search_guide",
             "set_setting",
             "team_check",
             "type_matchup"
           ]
  end

  describe "team_check" do
    test "Mudkip at level 5 before Roxanne is not ready", %{progress: progress} do
      assert {:ok, fact} = Tools.call("team_check", %{}, progress)
      assert fact.leader == "Roxanne"
      assert %{species: "nosepass", level: 15} = fact.ace
      assert [%{species: "mudkip", level_gap: -10, vs_ace: 2.0}] = fact.team
      assert fact.ready == false
    end

    test "Brawly at 1 badge, Wattson at 2 and never Flannery", %{progress: progress} do
      assert {:ok, %{leader: "Brawly"}} = Tools.call("team_check", %{}, %{progress | badges: [1]})

      team = [%{"species" => "marshtomp", "level" => 22}]

      assert {:ok, fact} =
               Tools.call("team_check", %{}, %{progress | badges: [1, 2], team: team})

      assert %{leader: "Wattson", ace: %{species: "manectric", level: 24}} = fact
      assert [%{level_gap: -2}] = fact.team
      refute Jason.encode!(fact) =~ ~r/Flannery|Lavaridge|Norman/
    end

    test "with all 8 badges there is no Next gym", %{progress: progress} do
      assert {:ok, %{next_gym: nil}} =
               Tools.call("team_check", %{}, %{progress | badges: Enum.to_list(1..8)})
    end
  end

  describe "type_matchup" do
    test "Water on Fire is 2 with its reason line", %{progress: progress} do
      assert {:ok, fact} =
               Tools.call(
                 "type_matchup",
                 %{"attacker" => "Water", "defender" => "fire"},
                 progress
               )

      assert %{multiplier: 2.0, reasons: ["Water puts out Fire."]} = fact
      assert fact.defender == %{name: "fire", types: ["fire"]}
    end

    test "Water on Geodude, Rock and Ground, is 4 at 0 badges", %{progress: progress} do
      assert {:ok, fact} =
               Tools.call(
                 "type_matchup",
                 %{"attacker" => "water", "defender" => "Geodude"},
                 progress
               )

      assert fact.defender == %{name: "geodude", types: ["rock", "ground"]}
      assert fact.multiplier == 4.0
      assert fact.reasons == ["Water wears rock away.", "Water turns ground to mud."]
    end

    test "Electric on Ground is 0 with its reason line", %{progress: progress} do
      assert {:ok, %{multiplier: +0.0, reasons: ["Electric cannot reach Ground."]}} =
               Tools.call(
                 "type_matchup",
                 %{"attacker" => "electric", "defender" => "ground"},
                 progress
               )
    end

    test "Roxanne means Nosepass: the 2x types and the types to avoid", %{progress: progress} do
      assert {:ok, fact} = Tools.call("type_matchup", %{"defender" => "Roxanne"}, progress)
      assert fact.defender == %{leader: "Roxanne", name: "nosepass", types: ["rock"]}

      assert Enum.map(fact.good, &{&1.type, &1.multiplier}) ==
               for(t <- ~w(fighting ground steel water grass), do: {t, 2.0})

      assert Enum.map(fact.avoid, &{&1.type, &1.multiplier}) ==
               for(t <- ~w(normal flying poison fire), do: {t, 0.5})

      assert %{reasons: ["Water wears rock away."]} = Enum.find(fact.good, &(&1.type == "water"))
    end

    test "Electric on Marshtomp is 0 and says only the Ground line", %{progress: progress} do
      team = [%{"species" => "marshtomp", "level" => 16}]

      assert {:ok, %{multiplier: +0.0, reasons: ["Electric cannot reach Ground."]}} =
               Tools.call(
                 "type_matchup",
                 %{"attacker" => "electric", "defender" => "Marshtomp"},
                 %{progress | team: team}
               )
    end

    test "an empty attacker means no attacker", %{progress: progress} do
      assert {:ok, %{good: [_ | _], avoid: [_ | _]}} =
               Tools.call("type_matchup", %{"attacker" => " ", "defender" => "rock"}, progress)
    end

    test "Fairy is not_found, as defender or attacker", %{progress: progress} do
      assert {:error, :not_found} = Tools.call("type_matchup", %{"defender" => "fairy"}, progress)

      assert {:error, :not_found} =
               Tools.call(
                 "type_matchup",
                 %{"attacker" => "fairy", "defender" => "rock"},
                 progress
               )
    end

    test "Wattson and Magneton at 0 badges are past_horizon, and named at 2", %{
      progress: progress
    } do
      for name <- ["Wattson", "Magneton"] do
        assert {:error, :past_horizon} =
                 Tools.call("type_matchup", %{"defender" => name}, progress)
      end

      assert {:ok, %{defender: %{leader: "Wattson", name: "manectric"}}} =
               Tools.call("type_matchup", %{"defender" => "Wattson"}, %{progress | badges: [1, 2]})

      assert {:ok, %{defender: %{name: "magneton"}}} =
               Tools.call("type_matchup", %{"defender" => "Magneton"}, %{
                 progress
                 | badges: [1, 2]
               })
    end

    test "no defender is a bad argument", %{progress: progress} do
      assert {:error, :bad_arguments} =
               Tools.call("type_matchup", %{"attacker" => "water"}, progress)
    end
  end

  describe "set_setting" do
    test "humor 60 is written and confirmed, and the new Progress has it", %{progress: progress} do
      assert {:logged, "Humor set to 60 percent.", %{humor: 60}} =
               Tools.call("set_setting", %{"name" => "humor", "value" => 60}, progress)

      assert GameData.progress("tools-test").humor == 60
    end

    test "spoilers stay locked at 0", %{progress: progress} do
      assert {:refused, line} =
               Tools.call("set_setting", %{"name" => "spoilers", "value" => 100}, progress)

      assert line =~ "Spoilers stay at 0"
      assert GameData.progress("tools-test") == progress
    end

    test "humor out of range, or not a whole number, is refused", %{progress: progress} do
      for value <- [140, -1, "60", 60.5, nil] do
        assert {:refused, _} =
                 Tools.call("set_setting", %{"name" => "humor", "value" => value}, progress)
      end

      assert GameData.progress("tools-test").humor == 75
    end

    test "the definition offers humor only, 0 to 100" do
      tool = Enum.find(Tools.definitions(), &(&1.function.name == "set_setting"))

      assert %{name: %{enum: ["humor"]}, value: %{type: "integer"}} =
               tool.function.parameters.properties

      assert tool.function.parameters.required == ["name", "value"]
    end
  end

  test "The tool offers set_level, not level_up, a team list and no slot" do
    log_event = Enum.find(Tools.definitions(), &(&1.function.name == "log_event"))
    %{kind: %{enum: kinds}, details: details} = log_event.function.parameters.properties

    assert "set_level" in kinds and "set_team" in kinds
    refute "level_up" in kinds
    assert Enum.sort(kinds) == Enum.sort(Maya.Events.kinds() -- ["level_up"])
    refute details.description =~ "level_up"
    assert details.description =~ "only when the player lists every member"

    assert %{type: "array", items: %{properties: %{species: _, level: _}}} =
             details.properties.team

    refute Map.has_key?(details.properties, :slot)
  end

  describe "search_guide" do
    defp guide(location, badges, progress) do
      args = if location, do: %{"location" => location}, else: %{}
      Tools.call("search_guide", args, %{progress | badges: badges})
    end

    defp note(name), do: Enum.find(notes(), &(&1["location"] == name))["text"]

    defp notes,
      do: "priv/data/walkthrough_notes.json" |> File.read!() |> Jason.decode!()

    test "with no location it is the current place's note", %{progress: progress} do
      assert guide(nil, [], progress) ==
               {:ok, %{location: "Littleroot Town", note: note("Littleroot Town")}}
    end

    test "a named place inside the horizon, any case", %{progress: progress} do
      assert {:ok, %{location: "Rustboro City"}} = guide("rustboro city", [], progress)
    end

    test "Dewford, Granite Cave and Slateport wait for badge 1", %{progress: progress} do
      for place <- ["Dewford Town", "Granite Cave", "Slateport City"] do
        assert guide(place, [], progress) == {:error, :past_horizon}
        assert {:ok, %{location: ^place}} = guide(place, [1], progress)
      end
    end

    test "Route 110 and Mauville City wait for badge 2", %{progress: progress} do
      for place <- ["Route 110", "Mauville City"] do
        assert guide(place, [1], progress) == {:error, :past_horizon}
        assert {:ok, %{location: ^place}} = guide(place, [1, 2], progress)
      end
    end

    test "unlisted and made-up places are both past_horizon", %{progress: progress} do
      assert guide("Verdanturf Town", [1, 2], progress) == {:error, :past_horizon}
      assert guide("Narnia", [1, 2], progress) == {:error, :past_horizon}
    end

    test "a listed place inside the horizon with no note is not_found", %{progress: progress} do
      Repo.delete_all(from n in "walkthrough_notes", where: n.location == "Route 101")
      assert guide("Route 101", [], progress) == {:error, :not_found}
    end

    test "a location that is not a string is a bad argument", %{progress: progress} do
      assert Tools.call("search_guide", %{"location" => 7}, progress) == {:error, :bad_arguments}
      assert Tools.call("search_guide", "Dewford", progress) == {:error, :bad_arguments}
    end
  end

  test "gym_counter for Roxanne from the imported data and the seed Team", %{progress: progress} do
    assert {:ok, fact} = Tools.call("gym_counter", %{"leader" => "Roxanne"}, progress)
    assert %{species: "nosepass", level: 15} = fact.ace
    assert fact.suggested_lead == "mudkip"
    assert [%{species: "mudkip", vs_ace: 2.0}] = fact.team
  end

  test "gym_counter past the horizon and unknown", %{progress: progress} do
    assert Tools.call("gym_counter", %{"leader" => "Wattson"}, progress) ==
             {:error, :past_horizon}

    assert Tools.call("gym_counter", %{"leader" => "Giovanni"}, progress) == {:error, :not_found}
  end

  test "find_pokemon for Ralts lists Route 102 only", %{progress: progress} do
    assert {:ok, %{types: ["psychic"], places: places}} =
             Tools.call("find_pokemon", %{"name" => "Ralts"}, progress)

    assert [%{location: "Route 102", method: "land", rate: 4}] = places
  end

  test "find_pokemon past the horizon and unknown", %{progress: progress} do
    assert Tools.call("find_pokemon", %{"name" => "Zubat"}, progress) == {:error, :past_horizon}
    assert Tools.call("find_pokemon", %{"name" => "Agumon"}, progress) == {:error, :not_found}
  end

  test "move_learnset for Mudkip stops at Roxanne's ace, level 15", %{progress: progress} do
    assert {:ok, %{name: "mudkip", level_horizon: 15, moves: moves}} =
             Tools.call("move_learnset", %{"species" => "Mudkip"}, progress)

    assert Enum.map(moves, &{&1.move, &1.level}) == [
             {"tackle", 1},
             {"growl", 1},
             {"mud-slap", 6},
             {"water-gun", 10},
             {"bide", 15}
           ]
  end

  test "move_learnset with every badge lists Endeavor", %{progress: progress} do
    progress = %{progress | badges: Enum.to_list(1..8)}

    assert {:ok, %{level_horizon: nil, moves: moves}} =
             Tools.call("move_learnset", %{"species" => "mudkip"}, progress)

    assert "endeavor" in Enum.map(moves, & &1.move)
  end

  test "move_learnset past the horizon, unknown and without species", %{progress: progress} do
    for name <- ["Groudon", "Marshtomp"] do
      assert Tools.call("move_learnset", %{"species" => name}, progress) ==
               {:error, :past_horizon}
    end

    assert Tools.call("move_learnset", %{"species" => "Agumon"}, progress) ==
             {:error, :not_found}

    assert Tools.call("move_learnset", %{}, progress) == {:error, :bad_arguments}
  end

  test "wrong arguments and unknown tools are errors, not crashes", %{progress: progress} do
    assert Tools.call("gym_counter", %{"name" => 1}, progress) == {:error, :bad_arguments}
    assert Tools.call("set_dial", %{}, progress) == {:error, :unknown_tool}
    assert {:refused, _} = Tools.call("set_setting", %{}, progress)
    assert Tools.call("log_event", %{"kind" => 1}, progress) == {:error, :bad_arguments}
  end

  test "results are encoded as JSON for the model, past horizon with a hint", %{
    progress: progress
  } do
    assert %{"fact" => %{"suggested_lead" => "mudkip"}} =
             Tools.call("gym_counter", %{"leader" => "Roxanne"}, progress)
             |> Tools.encode(progress)
             |> Jason.decode!()

    assert %{"error" => "past_horizon", "hint" => hint} =
             Jason.decode!(Tools.encode({:error, :past_horizon}, progress))

    assert hint =~ "Roxanne"
    assert %{"error" => "not_found"} = Jason.decode!(Tools.encode({:error, :not_found}, progress))
  end

  test "log_event writes the Event and returns the new Progress with its confirm line", %{
    progress: progress
  } do
    args = %{"kind" => "badge_earned", "details" => %{"leader" => "Roxanne"}}

    assert {:logged, "Stone Badge logged. Mudkip would approve.", %{badges: [1]}} =
             result = Tools.call("log_event", args, progress)

    assert Jason.decode!(Tools.encode(result, progress)) == %{
             "confirm" => "Stone Badge logged. Mudkip would approve."
           }

    assert GameData.progress("tools-test").badges == [1]
  end

  test "log_event refusals are a line for the model; details may be left out", %{
    progress: progress
  } do
    refused = Tools.call("log_event", %{"kind" => "badge_earned"}, progress)
    assert refused == {:refused, "I can only log Roxanne's badge next."}
    assert Jason.decode!(Tools.encode(refused, progress)) == %{"refused" => elem(refused, 1)}
  end

  describe "find_trainer" do
    test "Route 102 at 0 badges: Calvin's first party, never a rematch", %{progress: progress} do
      assert {:ok, %{place: "Route 102", trainers: trainers}} =
               Tools.call("find_trainer", %{"place" => "Route 102"}, progress)

      assert %{name: "Calvin", pokemon: [%{species: "poochyena", level: 5}]} in trainers
      party = for t <- trainers, p <- t.pokemon, do: p
      refute Enum.any?(party, &(&1.species == "mightyena" or &1.level > 15))
    end

    test "Route 110 waits for badge 2, Dewford Town for badge 1", %{progress: progress} do
      for {place, badges} <- [{"Route 110", []}, {"Route 110", [1]}, {"Dewford Town", []}] do
        assert {:error, :past_horizon} =
                 Tools.call("find_trainer", %{"place" => place}, %{progress | badges: badges})
      end

      assert {:ok, %{place: "Route 110", trainers: [_ | _]}} =
               Tools.call("find_trainer", %{"place" => "Route 110"}, %{progress | badges: [1, 2]})
    end

    test "the rival on Route 103 has only the party for the seeded Mudkip (F5)",
         %{progress: progress} do
      assert {:ok, %{trainers: trainers}} =
               Tools.call("find_trainer", %{"place" => "Route 103"}, progress)

      assert [%{name: "May or Brendan", pokemon: [%{species: "treecko", level: 5}]}] = trainers
    end

    test "east Route 103 waits for Route 110, and swimmers for Surf", %{progress: progress} do
      assert {:ok, %{trainers: trainers}} =
               Tools.call("find_trainer", %{"place" => "Route 103"}, %{progress | badges: [1, 2]})

      names = Enum.map(trainers, & &1.name)
      assert "Daisy" in names and "Rhett" in names
      refute "Pete" in names or "Isabelle" in names

      assert {:ok, %{trainers: swimmers}} =
               Tools.call("find_trainer", %{"place" => "Route 105"}, %{progress | badges: [1]})

      refute "Luis" in Enum.map(swimmers, & &1.name)
    end

    test "gym trainers are under their city with the gym's own badges", %{progress: progress} do
      assert {:ok, %{trainers: trainers}} =
               Tools.call("find_trainer", %{"place" => "Rustboro City"}, progress)

      assert "Roxanne" in Enum.map(trainers, & &1.name)
    end

    test "an unlisted place fails closed, and a missing place is bad arguments",
         %{progress: progress} do
      assert {:error, :past_horizon} =
               Tools.call("find_trainer", %{"place" => "Lavaridge Town"}, progress)

      assert {:error, :bad_arguments} = Tools.call("find_trainer", %{}, progress)
    end
  end

  describe "find_item" do
    test "HM03 Surf names no place at 0 or 2 badges, including Petalburg City",
         %{progress: progress} do
      for badges <- [[], [1, 2]], name <- ["HM03", "Surf"] do
        assert {:error, :past_horizon} =
                 Tools.call("find_item", %{"name" => name}, %{progress | badges: badges})
      end

      assert {:ok, %{places: [%{location: "Petalburg City", how: "gift"}]}} =
               Tools.call("find_item", %{"name" => "HM03"}, %{
                 progress
                 | badges: Enum.to_list(1..5)
               })
    end

    test "the Mach Bike waits for badge 2, then Mauville City gives it", %{progress: progress} do
      assert {:error, :past_horizon} =
               Tools.call("find_item", %{"name" => "Mach Bike"}, %{progress | badges: [1]})

      assert {:ok, %{item: "mach bike", places: [%{location: "Mauville City", how: "gift"}]}} =
               Tools.call("find_item", %{"name" => "Mach Bike"}, %{progress | badges: [1, 2]})
    end

    test "Flash is a gift in Granite Cave from badge 1", %{progress: progress} do
      assert {:ok, %{item: "hm05 flash", places: [%{location: "Granite Cave", how: "gift"}]}} =
               Tools.call("find_item", %{"name" => "Flash"}, %{progress | badges: [1]})
    end

    test "a Great Ball at 1 badge is sold in Slateport City, never Mauville City",
         %{progress: progress} do
      assert {:ok, %{places: places}} =
               Tools.call("find_item", %{"name" => "Great Ball"}, %{progress | badges: [1]})

      assert %{location: "Slateport City", how: "mart"} in places
      refute Enum.any?(places, &(&1.location == "Mauville City"))
    end

    test "a Potion at 0 badges includes the ball on Route 102", %{progress: progress} do
      assert {:ok, %{places: places}} =
               Tools.call("find_item", %{"name" => "potion"}, progress)

      assert %{location: "Route 102", how: "ball"} in places
    end

    test "an item only behind Surf or Cut waits for that HM's badge (F6)", %{progress: progress} do
      for {name, badges} <- [
            {"Max Revive", [1, 2]},
            {"Star Piece", [1, 2]},
            {"X Accuracy", []}
          ] do
        assert {:error, :past_horizon} =
                 Tools.call("find_item", %{"name" => name}, %{progress | badges: badges})
      end

      assert {:ok, %{places: [%{location: "Route 104", how: "ball"}]}} =
               Tools.call("find_item", %{"name" => "X Accuracy"}, %{progress | badges: [1]})

      assert {:ok, %{places: places}} =
               Tools.call("find_item", %{"name" => "Iron"}, %{progress | badges: [1]})

      assert places == [%{location: "Slateport City", how: "mart"}]
    end

    test "Master Sword is not an item", %{progress: progress} do
      assert {:error, :not_found} =
               Tools.call("find_item", %{"name" => "Master Sword"}, progress)

      assert {:error, :bad_arguments} = Tools.call("find_item", %{"name" => 3}, progress)
    end
  end
end
