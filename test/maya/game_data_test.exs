defmodule Maya.GameDataTest do
  use Maya.DataCase, async: true

  alias Maya.GameData
  alias Maya.Horizon

  @tables ~w(species type_matchups encounters trainers trainer_pokemon locations progress)

  setup do
    :ok = GameData.import!()
  end

  test "Roxanne's team and levels come from the imported data" do
    assert %{name: "Roxanne", gym_badge: 1, pokemon: team} = GameData.trainer("Roxanne1")

    assert Enum.map(team, &{&1.species, &1.level}) == [
             {"geodude", 12},
             {"geodude", 12},
             {"nosepass", 15}
           ]

    assert "rock-tomb" in List.last(team).moves
  end

  test "Ralts' Route 102 land encounter rate is 4 percent at level 4" do
    assert [%{rate: 4, min_level: 4, max_level: 4}] =
             for(
               e <- GameData.encounters("ralts"),
               e.map == "MAP_ROUTE102",
               e.method == "land",
               do: e
             )
  end

  test "species have their Generation III types and evolution levels" do
    assert %{types: ["water"], evolutions: [%{"into" => "marshtomp", "min_level" => 16}]} =
             GameData.species("mudkip")

    assert %{types: ["normal"]} = GameData.species("azurill")
    assert GameData.multiplier("ghost", "steel") == 0.5
    assert GameData.multiplier("water", "rock") == 2.0
    assert GameData.multiplier("normal", "water") == 1.0
  end

  test "locations are Littleroot Town to Rustboro City; anything else fails closed" do
    names = for l <- GameData.locations(), do: l.name

    assert Enum.sort(names) ==
             Enum.sort([
               "Littleroot Town",
               "Route 101",
               "Oldale Town",
               "Route 103",
               "Route 102",
               "Petalburg City",
               "Route 104",
               "Petalburg Woods",
               "Rustboro City"
             ])

    progress = GameData.progress()
    assert Horizon.allowed?(GameData.location("Rustboro City"), progress)
    assert GameData.location("Route 110") == nil
    refute Horizon.allowed?(GameData.location("Route 110"), progress)
    refute Horizon.allowed?(GameData.location("Route 110"), %{badges: [1]})
  end

  test "Progress is seeded from priv/progress.json" do
    assert %{
             badges: [],
             team: [%{"species" => "mudkip", "level" => 5}],
             location: "Littleroot Town",
             humor: 75
           } = GameData.progress()

    assert %{badge: 1, leader: "Roxanne"} = Horizon.next_gym(GameData.progress())
  end

  test "a second import keeps Progress and gives the same rows" do
    counts = row_counts()
    Repo.query!("UPDATE progress SET badges = '{1}'")

    :ok = GameData.import!()

    assert row_counts() == counts
    assert %{badges: [1]} = GameData.progress()
    assert %{badge: 2, leader: "Brawly"} = Horizon.next_gym(GameData.progress())
  end

  defp row_counts, do: Map.new(@tables, &{&1, Repo.aggregate(&1, :count)})
end
