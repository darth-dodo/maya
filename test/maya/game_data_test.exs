defmodule Maya.GameDataTest do
  use Maya.DataCase, async: true

  alias Maya.GameData
  alias Maya.Horizon

  @tables ~w(species type_matchups encounters trainers trainer_pokemon locations learnsets walkthrough_notes progress)

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

  test "locations are Littleroot Town to Mauville City; anything else fails closed" do
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
             "Dewford Town" => 1,
             "Granite Cave" => 1,
             "Route 109" => 1,
             "Slateport City" => 1,
             "Route 107" => 2,
             "Route 108" => 2,
             "Route 110" => 2,
             "Mauville City" => 2
           }

    one_badge = %{badges: [1]}
    two_badges = %{badges: [1, 2]}

    for place <- ["Route 104", "Dewford Town", "Granite Cave", "Slateport City"],
        do: assert(Horizon.allowed?(GameData.location(place), one_badge))

    for place <- ["Route 110", "Mauville City"] do
      refute Horizon.allowed?(GameData.location(place), one_badge)
      assert Horizon.allowed?(GameData.location(place), two_badges)
    end

    for place <- ["Dewford Town", "Granite Cave", "Slateport City", "Route 116"],
        do: refute(Horizon.allowed?(GameData.location(place), %{badges: []}))

    progress = GameData.progress("guest-a")
    assert Horizon.allowed?(GameData.location("Rustboro City"), progress)

    for place <- ["Verdanturf Town", "Route 111"] do
      assert GameData.location(place) == nil
      refute Horizon.allowed?(GameData.location(place), two_badges)
    end
  end

  test "Walkthrough notes: one per location, with its badges, filtered by badges earned" do
    notes = Repo.all(from n in "walkthrough_notes", select: {n.location, n.badges_required})

    assert Enum.sort(notes) ==
             Enum.sort(for l <- GameData.locations(), do: {l.name, l.badges_required})

    assert GameData.walkthrough_note("Rustboro City", 0) =~ "Roxanne"
    assert GameData.walkthrough_note("Mauville City", 1) == nil
    assert GameData.walkthrough_note("Mauville City", 2) =~ "Wattson"
  end

  test "a notes file with a note for an unlisted place fails the import and changes nothing" do
    priv = Path.join(System.tmp_dir!(), "maya-notes-#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(priv, "data"))
    on_exit(fn -> File.rm_rf!(priv) end)

    for file <- File.ls!("priv/data"), do: File.cp!("priv/data/#{file}", "#{priv}/data/#{file}")

    File.write!(
      "#{priv}/data/walkthrough_notes.json",
      ~s([{"location":"Verdanturf Town","badges_required":3,"text":"Quiet."}])
    )

    counts = row_counts()
    assert_raise ArgumentError, ~r/Verdanturf Town/, fn -> GameData.import!(priv) end
    assert row_counts() == counts
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
