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

  test "species names are normalized to PokeAPI names" do
    assert Facts.species_name("  Mr Mime ") == "mr-mime"
    assert Facts.species_name("Ralts") == "ralts"
  end

  test "the past-horizon hint names the Next gym's leader and no place" do
    hint = Facts.hint(@progress)
    assert hint =~ "Roxanne"
    refute hint =~ Horizon.next_gym(@progress).city
  end
end
