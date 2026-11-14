defmodule Maya.GameData.ParseTest do
  use ExUnit.Case, async: true

  alias Maya.GameData.Parse

  @parties """
  static const struct TrainerMonNoItemDefaultMoves sParty_Calvin1[] = {
      {
      .iv = 0,
      .lvl = 5,
      .species = SPECIES_POOCHYENA,
      }
  };

  static const struct TrainerMonItemCustomMoves sParty_Roxanne1[] = {
      {
      .iv = 100,
      .lvl = 12,
      .species = SPECIES_GEODUDE,
      .heldItem = ITEM_NONE,
      .moves = {MOVE_TACKLE, MOVE_DEFENSE_CURL, MOVE_ROCK_THROW, MOVE_ROCK_TOMB}
      },
      {
      .iv = 100,
      .lvl = 12,
      .species = SPECIES_GEODUDE,
      .heldItem = ITEM_NONE,
      .moves = {MOVE_TACKLE, MOVE_DEFENSE_CURL, MOVE_ROCK_THROW, MOVE_ROCK_TOMB}
      },
      {
      .iv = 200,
      .lvl = 15,
      .species = SPECIES_NOSEPASS,
      .heldItem = ITEM_ORAN_BERRY,
      .moves = {MOVE_BLOCK, MOVE_HARDEN, MOVE_TACKLE, MOVE_ROCK_TOMB}
      }
  };
  """

  describe "parties/1" do
    test "parses Roxanne's first party and tags it with badge 1" do
      [calvin, roxanne] = Parse.parties(@parties)

      assert %{"label" => "Calvin1", "name" => "Calvin", "gym_badge" => nil} = calvin
      assert [%{"species" => "poochyena", "level" => 5, "moves" => []}] = calvin["pokemon"]

      assert %{"label" => "Roxanne1", "name" => "Roxanne", "gym_badge" => 1} = roxanne

      assert Enum.map(roxanne["pokemon"], &{&1["species"], &1["level"]}) == [
               {"geodude", 12},
               {"geodude", 12},
               {"nosepass", 15}
             ]

      assert List.last(roxanne["pokemon"])["moves"] == ["block", "harden", "tackle", "rock-tomb"]
    end
  end

  describe "constant_name/1" do
    test "turns pokeemerald constants into PokeAPI names" do
      assert Parse.constant_name("SPECIES_NIDORAN_F") == "nidoran-f"
      assert Parse.constant_name("SPECIES_MR_MIME") == "mr-mime"
      assert Parse.constant_name("MOVE_ROCK_TOMB") == "rock-tomb"
    end
  end

  describe "encounters/1" do
    test "sums slot rates per species and keeps level range" do
      json = %{
        "wild_encounter_groups" => [
          %{
            "label" => "gWildMonHeaders",
            "fields" => [
              %{
                "type" => "land_mons",
                "encounter_rates" => [20, 20, 10, 10, 10, 10, 5, 5, 4, 4, 1, 1]
              }
            ],
            "encounters" => [
              %{
                "map" => "MAP_ROUTE102",
                "land_mons" => %{
                  "mons" =>
                    Enum.map(
                      [
                        {"POOCHYENA", 3},
                        {"WURMPLE", 3},
                        {"POOCHYENA", 4},
                        {"WURMPLE", 4},
                        {"LOTAD", 3},
                        {"LOTAD", 4},
                        {"ZIGZAGOON", 3},
                        {"ZIGZAGOON", 3},
                        {"ZIGZAGOON", 4},
                        {"RALTS", 4},
                        {"ZIGZAGOON", 4},
                        {"SEEDOT", 3}
                      ],
                      fn {sp, lvl} ->
                        %{"min_level" => lvl, "max_level" => lvl, "species" => "SPECIES_" <> sp}
                      end
                    )
                }
              }
            ]
          },
          %{"label" => "gBattlePyramidWildMonHeaders", "fields" => [], "encounters" => []}
        ]
      }

      rows = Parse.encounters(json)
      ralts = Enum.find(rows, &(&1["species"] == "ralts"))

      assert ralts == %{
               "map" => "MAP_ROUTE102",
               "method" => "land",
               "species" => "ralts",
               "rate" => 4,
               "min_level" => 4,
               "max_level" => 4
             }

      assert %{"rate" => 30, "min_level" => 3, "max_level" => 4} =
               Enum.find(rows, &(&1["species"] == "poochyena"))

      assert rows |> Enum.map(& &1["rate"]) |> Enum.sum() == 100
    end

    test "keeps only the first header of a map (Altering Cave has 9, the game uses the first)" do
      field = %{"type" => "land_mons", "encounter_rates" => [100]}

      header = fn sp ->
        %{
          "map" => "MAP_ALTERING_CAVE",
          "land_mons" => %{"mons" => [%{"min_level" => 10, "max_level" => 10, "species" => sp}]}
        }
      end

      json = %{
        "wild_encounter_groups" => [
          %{
            "label" => "gWildMonHeaders",
            "fields" => [field],
            "encounters" => [header.("SPECIES_ZUBAT"), header.("SPECIES_MAREEP")]
          }
        ]
      }

      assert [%{"species" => "zubat", "rate" => 100}] = Parse.encounters(json)
    end
  end

  describe "gen3_types/1" do
    test "uses past_types for the earliest generation at or after III" do
      clefairy = %{
        "types" => [%{"slot" => 1, "type" => %{"name" => "fairy"}}],
        "past_types" => [
          %{
            "generation" => %{"name" => "generation-v"},
            "types" => [%{"slot" => 1, "type" => %{"name" => "normal"}}]
          }
        ]
      }

      assert Parse.gen3_types(clefairy) == ["normal"]
    end

    test "ignores past_types that ended before Generation III" do
      magnemite = %{
        "types" => [
          %{"slot" => 1, "type" => %{"name" => "electric"}},
          %{"slot" => 2, "type" => %{"name" => "steel"}}
        ],
        "past_types" => [
          %{
            "generation" => %{"name" => "generation-i"},
            "types" => [%{"slot" => 1, "type" => %{"name" => "electric"}}]
          }
        ]
      }

      assert Parse.gen3_types(magnemite) == ["electric", "steel"]
    end
  end

  describe "gen3_matchups/1" do
    test "uses past damage relations and drops Fairy and neutral pairs" do
      ghost = %{
        "name" => "ghost",
        "damage_relations" => %{
          "no_damage_to" => [%{"name" => "normal"}],
          "half_damage_to" => [%{"name" => "dark"}],
          "double_damage_to" => [%{"name" => "ghost"}, %{"name" => "psychic"}]
        },
        "past_damage_relations" => [
          %{
            "generation" => %{"name" => "generation-v"},
            "damage_relations" => %{
              "no_damage_to" => [%{"name" => "normal"}],
              "half_damage_to" => [%{"name" => "dark"}, %{"name" => "steel"}],
              "double_damage_to" => [%{"name" => "ghost"}, %{"name" => "psychic"}]
            }
          }
        ]
      }

      rows = Parse.gen3_matchups(ghost)

      assert %{"attacker" => "ghost", "defender" => "steel", "multiplier" => 0.5} in rows
      assert %{"attacker" => "ghost", "defender" => "normal", "multiplier" => 0.0} in rows
      assert length(rows) == 5

      fairy = %{
        "name" => "fairy",
        "damage_relations" => %{"double_damage_to" => [%{"name" => "dragon"}]}
      }

      assert Parse.gen3_matchups(fairy) == []

      steel = %{
        "name" => "steel",
        "damage_relations" => %{
          "half_damage_to" => [%{"name" => "fire"}],
          "double_damage_to" => [%{"name" => "fairy"}]
        }
      }

      assert Parse.gen3_matchups(steel) == [
               %{"attacker" => "steel", "defender" => "fire", "multiplier" => 0.5}
             ]
    end
  end

  describe "evolutions/1" do
    test "maps each species to its Generation III evolutions with levels" do
      chain = %{
        "chain" => %{
          "species" => %{
            "name" => "ralts",
            "url" => "https://pokeapi.co/api/v2/pokemon-species/280/"
          },
          "evolution_details" => [],
          "evolves_to" => [
            %{
              "species" => %{
                "name" => "kirlia",
                "url" => "https://pokeapi.co/api/v2/pokemon-species/281/"
              },
              "evolution_details" => [%{"min_level" => 20, "trigger" => %{"name" => "level-up"}}],
              "evolves_to" => [
                %{
                  "species" => %{
                    "name" => "gardevoir",
                    "url" => "https://pokeapi.co/api/v2/pokemon-species/282/"
                  },
                  "evolution_details" => [
                    %{"min_level" => 30, "trigger" => %{"name" => "level-up"}}
                  ],
                  "evolves_to" => []
                },
                %{
                  "species" => %{
                    "name" => "gallade",
                    "url" => "https://pokeapi.co/api/v2/pokemon-species/475/"
                  },
                  "evolution_details" => [
                    %{"min_level" => nil, "trigger" => %{"name" => "use-item"}}
                  ],
                  "evolves_to" => []
                }
              ]
            }
          ]
        }
      }

      assert Parse.evolutions(chain) == %{
               "ralts" => [%{"into" => "kirlia", "min_level" => 20, "trigger" => "level-up"}],
               "kirlia" => [%{"into" => "gardevoir", "min_level" => 30, "trigger" => "level-up"}],
               "gardevoir" => []
             }
    end
  end
end
