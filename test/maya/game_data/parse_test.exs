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

  describe "learnset/2" do
    defp detail(group, method, level),
      do: %{
        "version_group" => %{"name" => group},
        "move_learn_method" => %{"name" => method},
        "level_learned_at" => level
      }

    test "keeps Emerald level-up rows only, in level order" do
      mudkip = %{
        "moves" => [
          %{
            "move" => %{"name" => "water-gun"},
            "version_group_details" => [
              detail("ruby-sapphire", "level-up", 7),
              detail("emerald", "level-up", 10)
            ]
          },
          %{
            "move" => %{"name" => "tackle"},
            "version_group_details" => [detail("emerald", "level-up", 1)]
          },
          %{
            "move" => %{"name" => "surf"},
            "version_group_details" => [detail("emerald", "machine", 0)]
          },
          %{
            "move" => %{"name" => "mud-shot"},
            "version_group_details" => [detail("diamond-pearl", "level-up", 25)]
          }
        ]
      }

      assert Parse.learnset("mudkip", mudkip) == [
               %{"species" => "mudkip", "move" => "tackle", "method" => "level-up", "level" => 1},
               %{
                 "species" => "mudkip",
                 "move" => "water-gun",
                 "method" => "level-up",
                 "level" => 10
               }
             ]
    end
  end

  describe "trainer and item places" do
    @trainers_h """
    const struct Trainer gTrainers[] = {
        [TRAINER_NONE] =
        {
            .trainerName = _(""),
            .partySize = 0,
        },

        [TRAINER_CALVIN_1] =
        {
            .trainerName = _("CALVIN"),
            .party = NO_ITEM_DEFAULT_MOVES(sParty_Calvin1),
        },

        [TRAINER_AMY_AND_LIV_1] =
        {
            .trainerName = _("AMY & LIV"),
            .party = NO_ITEM_DEFAULT_MOVES(sParty_AmyAndLiv1),
        },
    };
    """

    @route102_scripts """
    Route102_EventScript_Calvin::
    \ttrainerbattle_single TRAINER_CALVIN_1, Route102_Text_CalvinIntro, Route102_Text_CalvinDefeated
    \tgoto_if_defeated TRAINER_RICK, Route102_EventScript_Rick
    Route102_EventScript_CalvinRematch::
    \ttrainerbattle_rematch TRAINER_CALVIN_1, Route102_Text_CalvinRematchIntro, Route102_Text_CalvinRematchDefeated
    """

    test "a trainer constant gives its first party label and spoken name; the empty one is skipped" do
      assert Parse.trainer_constants(@trainers_h) == %{
               "TRAINER_CALVIN_1" => {"Calvin1", "Calvin"},
               "TRAINER_AMY_AND_LIV_1" => {"AmyAndLiv1", "Amy & Liv"}
             }
    end

    test "a map script's battles are its trainer constants, once each, never a goto" do
      assert Parse.trainer_battles(@route102_scripts) == ["TRAINER_CALVIN_1"]
    end

    test "an item ball and a hidden item come from map.json and item_ball_scripts.inc" do
      balls =
        Parse.ball_scripts("""
        Route102_EventScript_ItemPotion::
        \tfinditem ITEM_POTION
        \tend
        """)

      map = %{
        "id" => "MAP_ROUTE102",
        "object_events" => [
          %{"script" => "Route102_EventScript_Calvin"},
          %{"script" => "Route102_EventScript_ItemPotion"}
        ],
        "bg_events" => [
          %{"type" => "sign", "script" => "Route102_EventScript_RouteSign"},
          %{"type" => "hidden_item", "item" => "ITEM_ANTIDOTE"}
        ]
      }

      assert Parse.map_items(map, balls) == [{"ITEM_POTION", "ball"}, {"ITEM_ANTIDOTE", "hidden"}]
    end

    test "a mart is its first pokemart list; an expanded list behind a flag is left out" do
      scripts = """
      \tgoto_if_set FLAG_ADVENTURE_STARTED, OldaleTown_Mart_ExpandedItems
      \tpokemart OldaleTown_Mart_Pokemart_Basic
      OldaleTown_Mart_Pokemart_Basic:
      \t.2byte ITEM_POTION
      \t.2byte ITEM_ANTIDOTE
      \tpokemartlistend
      OldaleTown_Mart_ExpandedItems::
      \tpokemart OldaleTown_Mart_Pokemart_Expanded
      OldaleTown_Mart_Pokemart_Expanded:
      \t.2byte ITEM_POKE_BALL
      \tpokemartlistend
      """

      assert Parse.pokemart(scripts) == ["ITEM_POTION", "ITEM_ANTIDOTE"]
      assert Parse.pokemart("\tmsgbox Text, MSGBOX_NPC") == []
    end

    test "item names from items.h and tms_hms.h, with the script aliases for TMs and HMs" do
      items_h = """
      enum {
          ITEM_NONE,
          ITEM_POKE_BALL,
          ITEM_034,
          ITEM_MACH_BIKE,
          ITEM_TM01,
          ITEM_HM01,
          ITEM_HM02,
          ITEMS_COUNT
      };
      """

      tms_hms_h = """
      #define FOREACH_TM(F) \\
          F(FOCUS_PUNCH)

      #define FOREACH_HM(F) \\
          F(CUT) \\
          F(ROCK_SMASH)

      #define FOREACH_TMHM(F)
      """

      assert Parse.item_constants(items_h, tms_hms_h) == %{
               "ITEM_POKE_BALL" => "poke ball",
               "ITEM_MACH_BIKE" => "mach bike",
               "ITEM_TM01" => "tm01 focus punch",
               "ITEM_TM_FOCUS_PUNCH" => "tm01 focus punch",
               "ITEM_HM01" => "hm01 cut",
               "ITEM_HM_CUT" => "hm01 cut",
               "ITEM_HM02" => "hm02 rock smash",
               "ITEM_HM_ROCK_SMASH" => "hm02 rock smash"
             }
    end

    test "map constants become map directories, interiors under their city" do
      assert Parse.map_dir("MAP_ROUTE102") == "Route102"
      assert Parse.map_dir("MAP_GRANITE_CAVE_1F") == "GraniteCave_1F"
      assert Parse.map_dir("MAP_GRANITE_CAVE_1F", "MAP_GRANITE_CAVE_1F") == "GraniteCave_1F"
      assert Parse.map_dir("MAP_RUSTBORO_CITY_MART", "MAP_RUSTBORO_CITY") == "RustboroCity_Mart"

      assert Parse.map_dir("MAP_ROUTE104_PRETTY_PETAL_FLOWER_SHOP", "MAP_ROUTE104") ==
               "Route104_PrettyPetalFlowerShop"
    end

    test "a gift is confirmed only by a giveitem of one of its constants" do
      assert Parse.gives?("\tgiveitem ITEM_HM_FLASH\n", ["ITEM_HM05", "ITEM_HM_FLASH"])
      refute Parse.gives?("\tcheckitem ITEM_HM_FLASH\n", ["ITEM_HM05", "ITEM_HM_FLASH"])
      refute Parse.gives?("\tgiveitem ITEM_HM_FLASHY\n", ["ITEM_HM_FLASH"])
    end
  end

  describe "map layouts" do
    test "metatile behaviors are the enum names by value" do
      text =
        "#define X\n\nenum {\n    MB_NORMAL,\n    MB_SECRET_BASE_WALL,\n    MB_TALL_GRASS,\n};\n"

      assert Parse.behaviors(text) == {"MB_NORMAL", "MB_SECRET_BASE_WALL", "MB_TALL_GRASS"}
    end

    test "metatile attribute files are keyed by tileset" do
      text = """
      const u16 gMetatiles_General[] = INCBIN_U16("data/tilesets/primary/general/metatiles.bin");
      const u16 gMetatileAttributes_General[] = INCBIN_U16("data/tilesets/primary/general/metatile_attributes.bin");
      """

      assert Parse.metatile_attributes(text) == %{
               "gTileset_General" => "data/tilesets/primary/general/metatile_attributes.bin"
             }
    end

    test "a trainer script label gives its trainer; a script with no battle is left out" do
      scripts = """
      Route103_EventScript_Daisy::
      \ttrainerbattle_single TRAINER_DAISY, Route103_Text_DaisyIntro, Route103_Text_DaisyDefeated
      \tmsgbox Route103_Text_DaisyPostBattle, MSGBOX_AUTOCLOSE
      \tend

      Route103_EventScript_Man::
      \tmsgbox Route103_Text_Man, MSGBOX_NPC
      \tend

      Route103_EventScript_Amy::
      \ttrainerbattle_double TRAINER_AMY_AND_LIV_1, Route103_Text_AmyIntro
      \tend
      """

      assert Parse.script_trainers(scripts) == %{
               "Route103_EventScript_Daisy" => "TRAINER_DAISY",
               "Route103_EventScript_Amy" => "TRAINER_AMY_AND_LIV_1"
             }
    end
  end
end
