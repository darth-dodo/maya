defmodule Maya.GameData.AccessMapTest do
  use ExUnit.Case, async: true

  import Bitwise

  alias Maya.GameData.AccessMap

  @layout %{
    "width" => 6,
    "height" => 2,
    "primary_tileset" => "gTileset_General",
    "secondary_tileset" => "gTileset_Petalburg"
  }

  @json %{
    "object_events" => [
      %{
        "graphics_id" => "OBJ_EVENT_GFX_CUTTABLE_TREE",
        "x" => 2,
        "y" => 0,
        "elevation" => 3,
        "script" => "EventScript_CutTree"
      },
      %{
        "graphics_id" => "OBJ_EVENT_GFX_BREAKABLE_ROCK",
        "x" => 1,
        "y" => 1,
        "elevation" => 3,
        "script" => "EventScript_RockSmash"
      },
      %{
        "graphics_id" => "OBJ_EVENT_GFX_ITEM_BALL",
        "x" => 4,
        "y" => 0,
        "elevation" => 0,
        "script" => "Route103_EventScript_ItemPPUp"
      },
      %{
        "graphics_id" => "OBJ_EVENT_GFX_WOMAN_2",
        "x" => 5,
        "y" => 1,
        "elevation" => 0,
        "script" => "Route103_EventScript_Daisy"
      }
    ],
    "bg_events" => [
      %{
        "type" => "sign",
        "x" => 3,
        "y" => 1,
        "elevation" => 0,
        "script" => "Route103_EventScript_Sign"
      },
      %{"type" => "hidden_item", "x" => 0, "y" => 1, "elevation" => 0, "item" => "ITEM_POTION"}
    ],
    "connections" => [
      %{"map" => "MAP_OLDALE_TOWN", "offset" => 0, "direction" => "down"},
      %{"map" => "MAP_ROUTE110", "offset" => -60, "direction" => "right"},
      %{"map" => "MAP_ROUTE101", "offset" => 0, "direction" => "up"}
    ],
    "warp_events" => [
      %{"x" => 0, "y" => 0, "elevation" => 0, "dest_map" => "MAP_OLDALE_TOWN_MART"},
      %{"x" => 3, "y" => 0, "elevation" => 0, "dest_map" => "MAP_ROUTE103_HOUSE"}
    ]
  }

  @scripts "Route103_EventScript_Daisy::\n\ttrainerbattle_single TRAINER_DAISY, A, B\n\tend\n"

  @context %{
    listed: %{
      "MAP_OLDALE_TOWN" => {0, "Oldale Town"},
      "MAP_ROUTE110" => {2, "Route 110"},
      "MAP_OLDALE_TOWN_MART" => {0, "Oldale Town"}
    },
    sizes: %{
      "MAP_OLDALE_TOWN" => %{"width" => 3, "height" => 4},
      "MAP_ROUTE110" => %{"width" => 4, "height" => 62}
    },
    attributes: %{"gTileset_General" => <<0::little-16>>, "gTileset_Petalburg" => <<>>},
    behaviors: {"MB_NORMAL"},
    balls: %{"Route103_EventScript_ItemPPUp" => "ITEM_PP_UP"},
    trainers: %{"TRAINER_DAISY" => {"Daisy", "Daisy"}},
    items: %{"ITEM_PP_UP" => "pp up", "ITEM_POTION" => "potion"}
  }

  @location %{"map" => "MAP_ROUTE103", "badges_required" => 0}

  defp decode(json \\ @json, context \\ @context) do
    map_bin = for _ <- 1..12, into: <<>>, do: <<3 <<< 12::little-16>>
    AccessMap.decode({@location, "Route103", @scripts, json, @layout, map_bin}, context)
  end

  test "a map's entries are its connection edges and warps to listed maps" do
    assert decode().entries == [
             {0, "Oldale Town", [{0, 1}, {1, 1}, {2, 1}]},
             {2, "Route 110", [{5, 0}, {5, 1}]},
             {0, "Oldale Town", [{0, 0}]}
           ]
  end

  test "a map's spots are its balls, hidden items and trainers; objects take their tile's elevation" do
    map = decode()
    assert map.items == [{"pp up", "ball", {4, 0, 3}}, {"potion", "hidden", {0, 1, 0}}]
    assert map.trainers == [{"Daisy", {5, 1, 3}}]
    assert map.grid.trees == MapSet.new([{2, 0}])
    assert map.grid.walls == MapSet.new([{1, 1}])
    assert elem(map.grid.tiles, 0) == {0, 3, "MB_NORMAL"}
  end

  test "an unknown item or trainer fails the fetch" do
    assert_raise ArgumentError, ~r/unknown item ITEM_PP_UP/, fn ->
      decode(@json, %{@context | items: %{"ITEM_POTION" => "potion"}})
    end

    assert_raise ArgumentError, ~r/unknown trainer TRAINER_DAISY/, fn ->
      decode(@json, %{@context | trainers: %{}})
    end
  end
end
