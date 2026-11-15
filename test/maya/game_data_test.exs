defmodule Maya.GameDataTest do
  use Maya.DataCase, async: true

  alias Maya.GameData
  alias Maya.Horizon

  @tables ~w(species type_matchups encounters trainers trainer_pokemon locations learnsets progress)

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

  test "Mudkip's Emerald level-up moves come in level order" do
    moves = GameData.learnset("mudkip")
    assert Enum.all?(moves, &(&1.method == "level-up"))

    assert Enum.take(Enum.map(moves, &{&1.move, &1.level}), 5) == [
             {"tackle", 1},
             {"growl", 1},
             {"mud-slap", 6},
             {"water-gun", 10},
             {"bide", 15}
           ]

    assert {"endeavor", 46} = moves |> List.last() |> then(&{&1.move, &1.level})
    assert GameData.learnset("agumon") == []
  end

  test "locations are Littleroot Town to Dewford Town; anything else fails closed" do
    required = Map.new(GameData.locations(), &{&1.name, &1.badges_required})

    assert required == %{
             "Littleroot Town" => 0,
             "Route 101" => 0,
             "Oldale Town" => 0,
             "Route 103" => 0,
             "Route 102" => 0,
             "Petalburg City" => 0,
             "Route 104" => 0,
             "Petalburg Woods" => 0,
             "Rustboro City" => 0,
             "Route 116" => 1,
             "Rusturf Tunnel" => 1,
             "Route 105" => 1,
             "Route 106" => 1,
             "Dewford Town" => 1
           }

    one_badge = %{badges: [1]}
    assert Horizon.allowed?(GameData.location("Route 104"), one_badge)
    assert Horizon.allowed?(GameData.location("Dewford Town"), one_badge)
    refute Horizon.allowed?(GameData.location("Mauville City"), one_badge)
    refute Horizon.allowed?(GameData.location("Dewford Town"), %{badges: []})
    refute Horizon.allowed?(GameData.location("Route 116"), %{badges: []})

    progress = GameData.progress("guest-a")
    assert Horizon.allowed?(GameData.location("Rustboro City"), progress)
    assert GameData.location("Route 110") == nil
    refute Horizon.allowed?(GameData.location("Route 110"), progress)
    refute Horizon.allowed?(GameData.location("Route 110"), %{badges: [1]})
  end

  test "the import seeds no Progress; a new guest's first read seeds it from priv/progress.json" do
    assert Repo.aggregate("progress", :count) == 0

    assert %{
             badges: [],
             team: [%{"species" => "mudkip", "level" => 5}],
             location: "Littleroot Town",
             humor: 75
           } = GameData.progress("guest-a")

    assert %{badge: 1, leader: "Roxanne"} = Horizon.next_gym(GameData.progress("guest-a"))
    assert Repo.aggregate("progress", :count) == 1
  end

  test "each guest has their own Progress" do
    GameData.progress("guest-a")
    Repo.query!("UPDATE progress SET badges = '{1}' WHERE guest_id = 'guest-a'")

    assert %{badges: [1]} = GameData.progress("guest-a")
    assert %{badges: []} = GameData.progress("guest-b")
    assert Repo.aggregate("progress", :count) == 2
  end

  test "a second import keeps Progress and gives the same rows" do
    GameData.progress("guest-a")
    counts = row_counts()
    Repo.query!("UPDATE progress SET badges = '{1}'")

    :ok = GameData.import!()

    assert row_counts() == counts
    assert %{badges: [1]} = GameData.progress("guest-a")
    assert %{badge: 2, leader: "Brawly"} = Horizon.next_gym(GameData.progress("guest-a"))
  end

  defp row_counts, do: Map.new(@tables, &{&1, Repo.aggregate(&1, :count)})
end
