defmodule Maya.Agent.FactsTest do
  use ExUnit.Case, async: true

  alias Maya.Agent.Facts
  alias Maya.Horizon

  @progress %{badges: [], team: [%{"species" => "mudkip", "level" => 5}]}

  @roxanne %{
    name: "Roxanne",
    pokemon: [
      %{species: "geodude", level: 12, moves: ["tackle", "rock-tomb"]},
      %{species: "geodude", level: 12, moves: ["tackle", "rock-tomb"]},
      %{species: "nosepass", level: 15, moves: ["block", "rock-tomb"]}
    ]
  }

  @types %{
    "geodude" => ["rock", "ground"],
    "nosepass" => ["rock"],
    "mudkip" => ["water"],
    "torchic" => ["fire"]
  }

  @chart %{{"water", "rock"} => 2.0, {"water", "ground"} => 2.0, {"fire", "rock"} => 0.5}

  describe "gym/1" do
    test "finds a leader by name, ignoring case and a trailing 's" do
      assert %{badge: 1} = Facts.gym("Roxanne")
      assert %{badge: 1} = Facts.gym(" roxanne's ")
      assert %{badge: 2} = Facts.gym("BRAWLY")
      assert Facts.gym("Professor Oak") == nil
    end
  end

  describe "gym_counter/5" do
    test "Roxanne: her team, her ace Nosepass, and Mudkip as the lead" do
      assert {:ok, fact} =
               Facts.gym_counter(Facts.gym("Roxanne"), @roxanne, @progress, @types, @chart)

      assert fact.leader == "Roxanne"

      assert Enum.map(fact.leader_team, &{&1.species, &1.level}) == [
               {"geodude", 12},
               {"geodude", 12},
               {"nosepass", 15}
             ]

      assert %{species: "nosepass", level: 15, types: ["rock"]} = fact.ace
      assert [%{species: "mudkip", level: 5, types: ["water"], vs_ace: 2.0}] = fact.team
      assert fact.suggested_lead == "mudkip"
    end

    test "the lead is the best matchup against the ace, then the higher level" do
      progress = %{
        @progress
        | team: [
            %{"species" => "torchic", "level" => 9},
            %{"species" => "mudkip", "level" => 5}
          ]
      }

      assert {:ok, %{suggested_lead: "mudkip", team: [%{vs_ace: 0.5}, %{vs_ace: 2.0}]}} =
               Facts.gym_counter(Facts.gym("Roxanne"), @roxanne, progress, @types, @chart)
    end

    test "a leader past the Next gym is past the horizon" do
      assert Facts.gym_counter(
               Facts.gym("Brawly"),
               %{name: "Brawly", pokemon: []},
               @progress,
               @types,
               @chart
             ) ==
               {:error, :past_horizon}
    end

    test "with all 8 badges every leader is inside the horizon" do
      progress = %{@progress | badges: Enum.to_list(1..8)}

      assert {:ok, _} =
               Facts.gym_counter(Facts.gym("Roxanne"), @roxanne, progress, @types, @chart)
    end

    test "an unknown leader or a missing party is not found" do
      assert Facts.gym_counter(nil, nil, @progress, @types, @chart) == {:error, :not_found}

      assert Facts.gym_counter(Facts.gym("Roxanne"), nil, @progress, @types, @chart) ==
               {:error, :not_found}
    end
  end

  describe "team_check/5" do
    defp team_check(team, badges \\ []) do
      progress = %{@progress | badges: badges, team: team}
      Facts.team_check(Horizon.next_gym(progress), @roxanne, progress, @types, @chart)
    end

    test "Mudkip at level 5 before Roxanne: gap minus 10, multiplier 2, not ready" do
      assert {:ok, fact} = team_check([%{"species" => "mudkip", "level" => 5}])
      assert fact.leader == "Roxanne"
      assert %{species: "nosepass", level: 15, types: ["rock"]} = fact.ace
      assert fact.team == [%{species: "mudkip", level: 5, level_gap: -10, vs_ace: 2.0}]
      assert fact.ready == false
      refute Map.has_key?(fact, :leader_team)
    end

    test "Mudkip at level 13 is ready: 2x and at most 3 levels below" do
      assert {:ok, %{ready: true}} = team_check([%{"species" => "mudkip", "level" => 13}])
      assert {:ok, %{ready: false}} = team_check([%{"species" => "mudkip", "level" => 11}])
    end

    test "any member at or above the ace's level is ready, whatever the matchup" do
      assert {:ok, %{ready: true}} = team_check([%{"species" => "torchic", "level" => 15}])
      assert {:ok, %{ready: false}} = team_check([%{"species" => "torchic", "level" => 14}])
    end

    test "an empty Team has no members and is not ready" do
      assert {:ok, %{team: [], ready: false}} = team_check([])
    end

    test "with all 8 badges there is no Next gym, only the hint" do
      assert {:ok, %{next_gym: nil, hint: hint}} =
               Facts.team_check(
                 nil,
                 nil,
                 %{@progress | badges: Enum.to_list(1..8)},
                 @types,
                 @chart
               )

      assert hint =~ "Every badge"
    end

    test "a missing party is not found" do
      assert Facts.team_check(Facts.gym("Roxanne"), nil, @progress, @types, @chart) ==
               {:error, :not_found}
    end
  end

  describe "starter/1 and the rival on find_trainer" do
    @rival (for who <- ["May", "Brendan"],
                {starter, mon} <- [
                  {"Treecko", "torchic"},
                  {"Torchic", "mudkip"},
                  {"Mudkip", "treecko"}
                ] do
              %{
                label: "#{who}Route103#{starter}",
                name: who,
                badges_required: 0,
                pokemon: [%{species: mon, level: 5}]
              }
            end)

    @route103 %{name: "Route 103", badges_required: 0}

    test "the starter is the one starter line in the Team or PC, else nil" do
      assert Facts.starter(%{team: [%{"species" => "marshtomp"}], box: []}) == "mudkip"
      assert Facts.starter(%{team: [], box: [%{"species" => "grovyle"}]}) == "treecko"
      assert Facts.starter(%{team: [%{"species" => "poochyena"}], box: []}) == nil

      two = [%{"species" => "mudkip"}, %{"species" => "torchic"}]
      assert Facts.starter(%{team: two, box: []}) == nil
      assert Facts.starter(%{team: [%{"species" => "mudkip"}]}) == "mudkip"
    end

    test "a known starter gets one rival party, May and Brendan merged when the same" do
      assert {:ok, %{trainers: [rival]}} = Facts.find_trainer(@route103, @rival, @progress)
      assert rival == %{name: "May or Brendan", pokemon: [%{species: "treecko", level: 5}]}
    end

    test "May and Brendan stay apart when their parties differ" do
      rows =
        Enum.map(@rival, fn
          %{label: "MayRoute103Mudkip"} = r -> %{r | pokemon: [%{species: "wingull", level: 5}]}
          r -> r
        end)

      assert {:ok, %{trainers: trainers}} = Facts.find_trainer(@route103, rows, @progress)
      assert Enum.map(trainers, & &1.name) == ["May", "Brendan"]
    end

    test "an unknown starter gets one line, never six parties" do
      progress = %{@progress | team: [%{"species" => "poochyena", "level" => 5}]}

      assert {:ok, %{trainers: [rival]}} = Facts.find_trainer(@route103, @rival, progress)
      assert rival == %{name: "May or Brendan", note: "The rival's team depends on your starter."}
    end
  end

  describe "find_pokemon/4" do
    @locations [
      %{name: "Route 102", map: "MAP_ROUTE102", badges_required: 0},
      %{name: "Dewford Town", map: "MAP_DEWFORD_TOWN", badges_required: 1}
    ]
    @ralts %{
      name: "ralts",
      types: ["psychic"],
      evolutions: [%{"into" => "kirlia", "min_level" => 20, "trigger" => "level-up"}]
    }

    test "keeps only places inside the horizon" do
      encounters = [
        %{map: "MAP_ROUTE102", method: "land", rate: 4, min_level: 4, max_level: 4},
        %{map: "MAP_DEWFORD_TOWN", method: "land", rate: 10, min_level: 9, max_level: 9},
        %{map: "MAP_UNLISTED", method: "land", rate: 10, min_level: 9, max_level: 9}
      ]

      assert {:ok, fact} = Facts.find_pokemon(@ralts, encounters, @locations, @progress)
      assert fact.name == "ralts"
      assert fact.types == ["psychic"]
      assert [%{"into" => "kirlia", "min_level" => 20}] = fact.evolutions

      assert fact.places == [
               %{location: "Route 102", method: "land", rate: 4, min_level: 4, max_level: 4}
             ]
    end

    test "a Pokémon found only past the horizon is past the horizon" do
      encounters = [
        %{map: "MAP_DEWFORD_TOWN", method: "land", rate: 10, min_level: 9, max_level: 9}
      ]

      assert Facts.find_pokemon(@ralts, encounters, @locations, @progress) ==
               {:error, :past_horizon}
    end

    test "a Team member with no wild places at all is a Fact with no places" do
      mudkip = %{name: "mudkip", types: ["water"], evolutions: []}
      assert {:ok, %{places: []}} = Facts.find_pokemon(mudkip, [], @locations, @progress)
    end

    test "a gift or legendary Pokémon off the Team is past the horizon, not its types" do
      for species <- [
            %{name: "groudon", types: ["ground"], evolutions: []},
            %{name: "beldum", types: ["steel", "psychic"], evolutions: [%{"into" => "metang"}]}
          ] do
        assert Facts.find_pokemon(species, [], @locations, @progress) == {:error, :past_horizon}
      end
    end

    test "an unknown Pokémon is not found" do
      assert Facts.find_pokemon(nil, [], @locations, @progress) == {:error, :not_found}
    end
  end

  describe "move_learnset/5" do
    @mudkip %{name: "mudkip", types: ["water"], evolutions: []}
    @moves for {move, level} <- [
                 {"tackle", 1},
                 {"growl", 1},
                 {"mud-slap", 6},
                 {"water-gun", 10},
                 {"bide", 15},
                 {"foresight", 19},
                 {"endeavor", 46}
               ],
               do: %{move: move, level: level, method: "level-up"}

    test "Mudkip at 0 badges lists moves up to Roxanne's ace at 15, none above" do
      assert {:ok, fact} = Facts.move_learnset(@mudkip, @moves, [], @progress, 15)
      assert fact.name == "mudkip"
      assert fact.level_horizon == 15

      assert Enum.map(fact.moves, &{&1.move, &1.level}) == [
               {"tackle", 1},
               {"growl", 1},
               {"mud-slap", 6},
               {"water-gun", 10},
               {"bide", 15}
             ]

      assert Enum.all?(fact.moves, &(&1.method == "level-up"))
    end

    test "a Team above the ace raises the level horizon" do
      progress = %{@progress | team: [%{"species" => "mudkip", "level" => 20}]}

      assert {:ok, %{level_horizon: 20, moves: moves}} =
               Facts.move_learnset(@mudkip, @moves, [], progress, 15)

      assert List.last(moves).move == "foresight"
    end

    test "with all 8 badges every move is listed, Endeavor included" do
      progress = %{@progress | badges: Enum.to_list(1..8)}

      assert {:ok, %{level_horizon: nil, moves: moves}} =
               Facts.move_learnset(@mudkip, @moves, [], progress, nil)

      assert List.last(moves).move == "endeavor"
    end

    test "a species off the Team with no wild place inside the horizon is past the horizon" do
      groudon = %{name: "groudon", types: ["ground"], evolutions: []}
      assert Facts.move_learnset(groudon, @moves, [], @progress, 15) == {:error, :past_horizon}
    end

    test "a wild species inside the horizon is a Fact" do
      ralts = %{name: "ralts", types: ["psychic"], evolutions: []}
      place = %{location: "Route 102", method: "land", rate: 4, min_level: 4, max_level: 4}
      assert {:ok, %{name: "ralts"}} = Facts.move_learnset(ralts, @moves, [place], @progress, 15)
    end

    test "an unknown species is not found" do
      assert Facts.move_learnset(nil, [], [], @progress, 15) == {:error, :not_found}
    end
  end

  describe "guide_location/2 and search_guide/3" do
    @rustboro %{name: "Rustboro City", badges_required: 0}
    @mauville %{name: "Mauville City", badges_required: 2}

    test "a place name matches trimmed, in any case, with a leading the dropped" do
      for name <- ["Rustboro City", "  rustboro city ", "the Rustboro City"] do
        assert Facts.guide_location(name, [@rustboro, @mauville]) == @rustboro
      end

      assert Facts.guide_location("Rustboro", [@rustboro]) == nil
    end

    test "a place inside the horizon with a note is a Fact" do
      assert Facts.search_guide(@rustboro, "Roxanne's gym.", @progress) ==
               {:ok, %{location: "Rustboro City", note: "Roxanne's gym."}}
    end

    test "past the horizon and unlisted are both past_horizon; no note is not_found" do
      assert Facts.search_guide(@mauville, nil, %{@progress | badges: [1]}) ==
               {:error, :past_horizon}

      assert Facts.search_guide(nil, nil, @progress) == {:error, :past_horizon}
      assert Facts.search_guide(@rustboro, nil, @progress) == {:error, :not_found}
    end
  end

  test "species names are normalized to PokeAPI names" do
    assert Facts.species_name("  Mr Mime ") == "mr-mime"
    assert Facts.species_name("Ralts") == "ralts"
  end

  test "the past-horizon hint names the Next gym's leader and no place" do
    hint = Facts.hint(@progress)
    assert hint =~ "Roxanne"
    refute hint =~ Horizon.next_gym(@progress).city
  end

  describe "find_item and find_trainer" do
    @potion [%{location: "Route 102", how: "ball", badges_required: 0}]

    test "an item whose only row is a ball on Route 102" do
      assert Facts.find_item("potion", @potion, @progress) ==
               {:ok, %{item: "potion", places: [%{location: "Route 102", how: "ball"}]}}
    end

    test "a known item with every row past the horizon is past_horizon; nil is not_found" do
      rows = [%{location: "Mauville City", how: "gift", badges_required: 2}]
      assert Facts.find_item("mach bike", rows, @progress) == {:error, :past_horizon}
      assert Facts.find_item(nil, [], @progress) == {:error, :not_found}
    end

    test "spoken item names: case, accents, apostrophes, and TMs or HMs by number or move" do
      names = ["poke ball", "kings rock", "hm05 flash", "mach bike", "tm39 rock tomb"]
      assert Facts.item_name("Poké Ball", names) == "poke ball"
      assert Facts.item_name("King's Rock", names) == "kings rock"
      assert Facts.item_name("HM05", names) == "hm05 flash"

      for heard <- ["HM 5", "HM5", "hm 05"],
          do: assert(Facts.item_name(heard, names) == "hm05 flash")

      assert Facts.item_name("TM 39", names) == "tm39 rock tomb"
      assert Facts.item_name("S.S. Ticket", ["ss ticket"]) == "ss ticket"
      assert Facts.item_name("flash", names) == "hm05 flash"
      assert Facts.item_name("Rock Tomb", names) == "tm39 rock tomb"
      assert Facts.item_name("the Mach Bike", names) == "mach bike"
      assert Facts.item_name("Mach", names) == nil
      assert Facts.item_name("Master Sword", names) == nil
    end

    test "find_trainer leaves out a trainer row past the horizon, and an unlisted place fails closed" do
      city = %{name: "Rustboro City", badges_required: 0}

      trainers = [
        %{name: "Josh", badges_required: 0, pokemon: [%{species: "geodude", level: 10}]},
        %{name: "Later", badges_required: 5, pokemon: []}
      ]

      assert {:ok, %{place: "Rustboro City", trainers: [%{name: "Josh"}]}} =
               Facts.find_trainer(city, trainers, @progress)

      assert Facts.find_trainer(nil, [], @progress) == {:error, :past_horizon}
    end
  end

  test "type_matchup on a leader whose ace has no types fails closed" do
    gym = Facts.gym("Roxanne")

    assert {:error, :not_found} =
             Facts.type_matchup(nil, {:gym, gym, @roxanne, %{}}, %{}, %{}, @progress)
  end
end
