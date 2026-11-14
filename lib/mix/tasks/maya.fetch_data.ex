defmodule Mix.Tasks.Maya.FetchData do
  @shortdoc "Downloads pokeemerald and PokeAPI data into priv/data/ (network, run by hand)"
  @moduledoc """
  Downloads `wild_encounters.json` and `trainer_parties.h` from pret/pokeemerald
  at a pinned commit, plus the species and types Maya needs from PokeAPI as of
  Generation III, and writes compact JSON into `priv/data/`. Commit the output.

  `priv/data/locations.json` is hand-written and never touched here.
  """
  use Mix.Task

  alias Maya.GameData.Parse

  # master on 2026-11-14; change only on purpose and review the data diff.
  @pokeemerald_sha "731ad5bfd6e6f265508d0efcca0ba42f9dcf5881"
  @pokeemerald "https://raw.githubusercontent.com/pret/pokeemerald/#{@pokeemerald_sha}/src/data/"
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

    species =
      evolutions
      |> Map.keys()
      |> Enum.sort()
      |> pmap(fn name ->
        %{
          "name" => name,
          "types" => name |> default_pokemon() |> Parse.gen3_types(),
          "evolutions" => evolutions[name]
        }
      end)

    matchups = Enum.flat_map(@types, &(get!(@pokeapi <> "type/" <> &1) |> Parse.gen3_matchups()))

    write!(dir, "encounters.json", encounters)
    write!(dir, "trainers.json", trainers)
    write!(dir, "species.json", species)
    write!(dir, "type_matchups.json", matchups)
    Mix.shell().info("pokeemerald #{@pokeemerald_sha}: wrote #{dir}")
  end

  defp default_pokemon(name) do
    %{"varieties" => varieties} = get!(@pokeapi <> "pokemon-species/" <> name)
    %{"pokemon" => %{"url" => url}} = Enum.find(varieties, & &1["is_default"])
    get!(url)
  end

  defp get!(url), do: Req.get!(url, retry: :transient, receive_timeout: 30_000).body

  defp pmap(list, fun) do
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
