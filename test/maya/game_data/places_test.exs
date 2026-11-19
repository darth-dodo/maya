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
    item_places: [%{"item" => "great ball", "map" => "MAP_MAUVILLE_CITY_MART", "how" => "mart"}],
    access: %{"items" => [], "trainers" => []}
  }

  test "an item or trainer behind an HM takes that HM's badge; an unmatched row is a problem" do
    ball = %{"item" => "max revive", "map" => "MAP_PETALBURG_CITY", "how" => "ball"}
    item = Map.put(ball, "badges_required", 5)
    trainer = %{"label" => "Wattson1", "map" => "MAP_MAUVILLE_CITY", "badges_required" => 5}
    data = %{@clean | item_places: [ball], access: %{"items" => [item], "trainers" => [trainer]}}

    assert Places.problems(data) == []
    assert [%{"item" => "max revive", "badges_required" => 5} | _] = Places.item_rows(data)
    assert [%{"trainer_label" => "Wattson1", "badges_required" => 5}] = Places.trainer_rows(data)

    bad = %{"items" => [%{item | "item" => "ether"}], "trainers" => []}

    assert Places.problems(%{data | access: bad}) ==
             [{"MAP_PETALBURG_CITY", :unknown_access}]
  end

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
