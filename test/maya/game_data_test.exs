defmodule Maya.GameDataTest do
  use Maya.DataCase, async: true

  alias Maya.GameData
  alias Maya.Horizon

  @tables ~w(species type_matchups encounters trainers trainer_pokemon locations learnsets walkthrough_notes type_reasons items trainer_places item_places progress)

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

  test "type reasons: one row per line of type_reasons.json, read with the chart" do
    lines = "priv/data/type_reasons.json" |> File.read!() |> Jason.decode!()
    assert Repo.aggregate("type_reasons", :count) == length(lines)
    assert GameData.type_reasons()[{"water", "fire"}] == "Water puts out Fire."
  end

  test "a reasons file with a bad row fails the import and changes nothing" do
    priv = Path.join(System.tmp_dir!(), "maya-reasons-#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(priv, "data"))
    on_exit(fn -> File.rm_rf!(priv) end)

    for file <- File.ls!("priv/data"), do: File.cp!("priv/data/#{file}", "#{priv}/data/#{file}")

    File.write!(
      "#{priv}/data/type_reasons.json",
      ~s([{"attacker":"fire","defender":"water","multiplier":2.0,"reason":"Fire boils water."}])
    )

    counts = row_counts()
    assert_raise ArgumentError, ~r/fire on water/, fn -> GameData.import!(priv) end
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

  test "the Humor dial is written for one guest only" do
    GameData.progress("guest-a")
    GameData.progress("guest-b")

    assert :ok = GameData.put_humor!("guest-a", 60)
    assert %{humor: 60} = GameData.progress("guest-a")
    assert %{humor: 75} = GameData.progress("guest-b")
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

  # A copy of priv/ with one data file replaced, for the fail-closed import checks.
  defp priv_with(file, json) do
    priv = Path.join(System.tmp_dir!(), "maya-places-#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(priv, "data"))
    on_exit(fn -> File.rm_rf!(priv) end)
    for f <- File.ls!("priv/data"), do: File.cp!("priv/data/#{f}", "#{priv}/data/#{f}")
    File.write!("#{priv}/data/#{file}", json)
    priv
  end

  test "an interior that needs fewer badges than its city fails the import and changes nothing" do
    interiors =
      "priv/data/interiors.json"
      |> File.read!()
      |> String.replace(
        ~s({"map":"MAP_MAUVILLE_CITY_MART","city":"Mauville City","badges_required":2}),
        ~s({"map":"MAP_MAUVILLE_CITY_MART","city":"Mauville City","badges_required":1})
      )

    assert interiors =~ ~s("MAP_MAUVILLE_CITY_MART","city":"Mauville City","badges_required":1)
    counts = row_counts()

    assert_raise ArgumentError, ~r/MAP_MAUVILLE_CITY_MART/, fn ->
      GameData.import!(priv_with("interiors.json", interiors))
    end

    assert row_counts() == counts
  end

  test "a gift that needs fewer badges than its city fails the import" do
    gifts =
      ~s([{"item":"mach bike","map":"MAP_MAUVILLE_CITY_BIKE_SHOP","city":"Mauville City","badges_required":1,"how":"gift"}])

    assert_raise ArgumentError, ~r/MAP_MAUVILLE_CITY_BIKE_SHOP/, fn ->
      GameData.import!(priv_with("gifts.json", gifts))
    end
  end

  test "interiors are hand-listed, never inherited, and each one was fetched" do
    data = fn f -> "priv/data/#{f}.json" |> File.read!() |> Jason.decode!() end
    interiors = data.("interiors")
    listed = MapSet.new(data.("locations"), & &1["map"])
    known = MapSet.union(listed, MapSet.new(interiors, & &1["map"]))

    refute Enum.any?(interiors, &String.starts_with?(&1["map"], "MAP_PETALBURG_CITY_GYM"))

    rows =
      Repo.all(from t in "trainer_places", select: t.map) ++
        Repo.all(from i in "item_places", where: i.how != "gift", select: i.map)

    assert Enum.all?(rows, &MapSet.member?(known, &1))
    # A mart sells something and a gym has trainers, so every interior map was fetched.
    assert Enum.all?(interiors, &(&1["map"] in rows))
  end

  test "trainer and item rows keep their own map's badges" do
    assert Repo.all(
             from t in "trainer_places",
               where: t.trainer_label == "Wattson1",
               select: {t.location, t.badges_required}
           ) == [{"Mauville City", 2}]

    assert Repo.all(
             from i in "item_places",
               where: i.map == "MAP_SLATEPORT_CITY_MART",
               select: i.badges_required,
               distinct: true
           ) == [1]
  end

  defp row_counts, do: Map.new(@tables, &{&1, Repo.aggregate(&1, :count)})
end
