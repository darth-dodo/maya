defmodule Mix.Tasks.Maya.FetchData do
  @shortdoc "Downloads pokeemerald and PokeAPI data into priv/data/ (network, run by hand)"
  @moduledoc """
  Downloads `wild_encounters.json` and `trainer_parties.h` from pret/pokeemerald
  at a pinned commit, plus the species, types and Emerald level-up learnsets Maya needs from
  PokeAPI as of Generation III, and writes compact JSON into `priv/data/`. Commit the output.

  It also reads, for each listed location and each hand-written interior
  (`priv/data/interiors.json`), the map's `scripts.inc` and `map.json`, and writes the
  trainers battled there (`trainer_places.json`), the item balls, hidden items and first
  mart list (`item_places.json`) and every item name (`items.json`). Each gift in
  `priv/data/gifts.json` must be a `giveitem` in its map's script, or the fetch fails.

  `priv/data/locations.json`, `interiors.json` and `gifts.json` are hand-written and never
  touched here. Last it runs `mix maya.fetch_access`, the map walk behind `access.json`.
  """
  use Mix.Task

  alias Maya.GameData.Parse

  # master on 2026-11-14; change only on purpose and review the data diff.
  @pokeemerald_sha "731ad5bfd6e6f265508d0efcca0ba42f9dcf5881"
  @pokeemerald_root "https://raw.githubusercontent.com/pret/pokeemerald/#{@pokeemerald_sha}/"
  @pokeemerald @pokeemerald_root <> "src/data/"
  @pokeapi "https://pokeapi.co/api/v2/"
  @types ~w(normal fighting flying poison ground rock bug ghost steel fire water grass electric psychic ice dragon dark)

  @impl Mix.Task
  def run(_args) do
    {:ok, _} = Application.ensure_all_started(:req)
    dir = Path.join(File.cwd!(), "priv/data")

    # raw.githubusercontent.com serves JSON as text/plain, so Req leaves it a string.
    encounters =
      get!(@pokeemerald <> "wild_encounters.json") |> Jason.decode!() |> Parse.encounters()

    trainers = get!(@pokeemerald <> "trainer_parties.h") |> Parse.parties()

    seen =
      Enum.map(encounters, & &1["species"]) ++
        for t <- trainers, p <- t["pokemon"], do: p["species"]

    evolutions =
      seen
      |> Enum.uniq()
      |> pmap(&get!(@pokeapi <> "pokemon-species/" <> &1)["evolution_chain"]["url"])
      |> Enum.uniq()
      |> pmap(&(&1 |> get!() |> Parse.evolutions()))
      |> Enum.reduce(&Map.merge/2)

    # One `pokemon` reply per species gives both its types and its learnset.
    {species, learnsets} =
      evolutions
      |> Map.keys()
      |> Enum.sort()
      |> pmap(fn name ->
        pokemon = default_pokemon(name)

        {%{
           "name" => name,
           "types" => Parse.gen3_types(pokemon),
           "evolutions" => evolutions[name]
         }, {pokemon["id"], Parse.learnset(name, pokemon)}}
      end)
      |> Enum.unzip()

    # Every Generation III species (national id up to 386) learns a move by level up in Emerald;
    # none means a renamed version group. Later babies in the chains (Budew) have no Emerald rows.
    empty = for {s, {id, []}} <- Enum.zip(species, learnsets), id <= 386, do: s["name"]
    if empty != [], do: Mix.raise("no Emerald learnset for #{Enum.join(empty, ", ")}")
    learnsets = Enum.flat_map(learnsets, &elem(&1, 1))

    matchups = Enum.flat_map(@types, &(get!(@pokeapi <> "type/" <> &1) |> Parse.gen3_matchups()))

    write!(dir, "encounters.json", encounters)
    write!(dir, "trainers.json", trainers)
    write!(dir, "species.json", species)
    write!(dir, "type_matchups.json", matchups)
    write!(dir, "learnsets.json", learnsets)
    places!(dir)
    Mix.shell().info("pokeemerald #{@pokeemerald_sha}: wrote #{dir}")
    Mix.Task.run("maya.fetch_access")
  end

  @doc false
  def pokeemerald_root, do: @pokeemerald_root

  defp places!(dir) do
    hand = &(dir |> Path.join(&1) |> File.read!() |> Jason.decode!())
    locations = hand.("locations.json")
    city_map = Map.new(locations, &{&1["name"], &1["map"]})

    constants =
      Parse.item_constants(
        get_ok!(@pokeemerald_root <> "include/constants/items.h"),
        get_ok!(@pokeemerald_root <> "include/constants/tms_hms.h")
      )

    item = fn c -> constants[c] || Mix.raise("unknown item #{c}") end
    trainers = get_ok!(@pokeemerald <> "trainers.h") |> Parse.trainer_constants()

    balls =
      get_ok!(@pokeemerald_root <> "data/scripts/item_ball_scripts.inc") |> Parse.ball_scripts()

    maps =
      Enum.map(locations, &{&1["map"], Parse.map_dir(&1["map"])}) ++
        Enum.map(
          hand.("interiors.json"),
          &{&1["map"], Parse.map_dir(&1["map"], city_map[&1["city"]])}
        )

    fetched = pmap(maps, fn {map, map_dir} -> {map, map!(map, map_dir)} end)

    trainer_places =
      for {map, {scripts, _}} <- fetched, c <- Parse.trainer_battles(scripts) do
        {label, name} = trainers[c] || Mix.raise("unknown trainer #{c} on #{map}")
        %{"map" => map, "label" => label, "name" => name}
      end

    item_places =
      for {map, {scripts, json}} <- fetched,
          {c, how} <-
            Parse.map_items(json, balls) ++ Enum.map(Parse.pokemart(scripts), &{&1, "mart"}),
          uniq: true,
          do: %{"item" => item.(c), "map" => map, "how" => how}

    for gift <- hand.("gifts.json") do
      {scripts, _} = map!(gift["map"], Parse.map_dir(gift["map"], city_map[gift["city"]]))
      names = for {c, name} <- constants, name == gift["item"], do: c

      unless Parse.gives?(scripts, names),
        do: Mix.raise("no giveitem for #{gift["item"]} in #{gift["map"]}")
    end

    write!(dir, "trainer_places.json", trainer_places)
    write!(dir, "item_places.json", item_places)
    write!(dir, "items.json", constants |> Map.values() |> Enum.uniq() |> Enum.sort())
  end

  # A map's scripts and decoded map.json; fails loudly on a missing map or a wrong directory.
  @doc false
  def map!(map, map_dir) do
    base = @pokeemerald_root <> "data/maps/" <> map_dir <> "/"
    json = (base <> "map.json") |> get_ok!() |> Jason.decode!()
    if json["id"] != map, do: Mix.raise("#{map_dir} is #{json["id"]}, not #{map}")
    {get_ok!(base <> "scripts.inc"), json}
  end

  @doc false
  def get_ok!(url) do
    case Req.get!(url, retry: :transient, receive_timeout: 30_000) do
      %{status: 200, body: body} -> body
      %{status: status} -> Mix.raise("#{status} for #{url}")
    end
  end

  defp default_pokemon(name) do
    %{"varieties" => varieties} = get!(@pokeapi <> "pokemon-species/" <> name)
    %{"pokemon" => %{"url" => url}} = Enum.find(varieties, & &1["is_default"])
    get!(url)
  end

  defp get!(url), do: Req.get!(url, retry: :transient, receive_timeout: 30_000).body

  @doc false
  def pmap(list, fun) do
    list
    |> Task.async_stream(fun, max_concurrency: 8, timeout: 120_000)
    |> Enum.map(fn {:ok, value} -> value end)
  end

  # One row per line: small files with readable diffs.
  defp write!(dir, file, rows) do
    File.mkdir_p!(dir)

    File.write!(
      Path.join(dir, file),
      "[\n" <> Enum.map_join(rows, ",\n", &Jason.encode!/1) <> "\n]\n"
    )
  end
end
