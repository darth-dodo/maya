defmodule Maya.GameData.PlacesTest do
  use ExUnit.Case, async: true

  alias Maya.GameData.Places

  @clean %{
    locations: [
      %{"name" => "Petalburg City", "map" => "MAP_PETALBURG_CITY", "badges_required" => 0},
      %{"name" => "Mauville City", "map" => "MAP_MAUVILLE_CITY", "badges_required" => 2}
    ],
    interiors: [
      %{"map" => "MAP_MAUVILLE_CITY_MART", "city" => "Mauville City", "badges_required" => 2}
    ],
    gifts: [
      %{
        "item" => "hm03 surf",
        "map" => "MAP_PETALBURG_CITY_WALLYS_HOUSE",
        "city" => "Petalburg City",
        "badges_required" => 5,
        "how" => "gift"
      }
    ],
    items: ["hm03 surf", "great ball"],
    trainers: [%{"label" => "Wattson1"}],
    trainer_places: [%{"map" => "MAP_MAUVILLE_CITY", "label" => "Wattson1", "name" => "Wattson"}],
    item_places: [%{"item" => "great ball", "map" => "MAP_MAUVILLE_CITY_MART", "how" => "mart"}]
  }

  test "clean data has no problems, and rows carry their own map's or gift's badges" do
    assert Places.problems(@clean) == []

    assert [%{"location" => "Mauville City", "badges_required" => 2}] =
             Places.trainer_rows(@clean)

    assert [
             %{"location" => "Mauville City", "badges_required" => 2, "how" => "mart"},
             %{"location" => "Petalburg City", "badges_required" => 5, "how" => "gift"}
           ] = Places.item_rows(@clean)
  end

  test "an unlisted city, an unlisted map, an unknown item or trainer is each a problem" do
    data = %{
      @clean
      | interiors: [
          %{
            "map" => "MAP_LAVARIDGE_TOWN_MART",
            "city" => "Lavaridge Town",
            "badges_required" => 4
          }
        ],
        gifts: [%{hd(@clean.gifts) | "item" => "master sword"}],
        trainer_places: [%{"map" => "MAP_ROUTE111", "label" => "Nobody", "name" => "Nobody"}]
    }

    assert Enum.sort(Places.problems(data)) ==
             Enum.sort([
               {"MAP_LAVARIDGE_TOWN_MART", :unlisted_city},
               {"MAP_ROUTE111", :unlisted_map},
               {"MAP_MAUVILLE_CITY_MART", :unlisted_map},
               {"master sword", :unknown_item},
               {"Nobody", :unknown_trainer}
             ])
  end
end
