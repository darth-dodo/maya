defmodule Maya.GameData do
  @moduledoc """
  Maya's game Facts and Progress in Postgres, loaded only from committed files
  (`priv/data/*.json`, `priv/progress.json`) by `import!/0`. No network.
  """

  import Ecto.Query

  alias Maya.Repo

  # Children before parents, so deletes never trip the trainer_pokemon foreign key.
  @game_tables ~w(trainer_pokemon trainers encounters type_matchups species locations)

  @doc """
  Replaces the game data tables from `priv/data/` in one transaction and seeds
  Progress from `priv/progress.json` only when there is none (ADR-006).
  """
  def import!(priv \\ Application.app_dir(:maya, "priv")) do
    data = fn file ->
      priv |> Path.join("data/#{file}.json") |> File.read!() |> Jason.decode!()
    end

    trainers = data.("trainers")

    {:ok, :ok} =
      Repo.transaction(fn ->
        Enum.each(@game_tables, &Repo.delete_all/1)
        insert!("species", data.("species"), ~w(name types evolutions))
        insert!("type_matchups", data.("type_matchups"), ~w(attacker defender multiplier))

        insert!(
          "encounters",
          data.("encounters"),
          ~w(map method species rate min_level max_level)
        )

        insert!("trainers", trainers, ~w(label name gym_badge))

        insert!(
          "trainer_pokemon",
          trainer_pokemon_rows(trainers),
          ~w(trainer_label slot species level moves)
        )

        insert!("locations", data.("locations"), ~w(name map badges_required))
        seed_progress!(priv |> Path.join("progress.json") |> File.read!() |> Jason.decode!())
      end)

    :ok
  end

  defp trainer_pokemon_rows(trainers) do
    for t <- trainers, {mon, slot} <- Enum.with_index(t["pokemon"], 1) do
      Map.merge(mon, %{"trainer_label" => t["label"], "slot" => slot})
    end
  end

  # Chunked to stay under Postgres' 65535 bind parameters per statement.
  defp insert!(table, rows, fields) do
    rows
    |> Enum.map(fn row -> Map.new(fields, &{String.to_existing_atom(&1), row[&1]}) end)
    |> Enum.chunk_every(1000)
    |> Enum.each(&Repo.insert_all(table, &1))
  end

  defp seed_progress!(seed) do
    now = DateTime.utc_now(:second)

    Repo.insert_all(
      "progress",
      [
        %{
          id: 1,
          badges: seed["badges"],
          team: seed["team"],
          location: seed["location"],
          humor: seed["humor"],
          inserted_at: now,
          updated_at: now
        }
      ],
      on_conflict: :nothing,
      conflict_target: :id
    )

    :ok
  end

  @doc "A trainer by pokeemerald party label (`Roxanne1`) with its party in order, or nil."
  def trainer(label) do
    with %{} = trainer <-
           Repo.one(
             from t in "trainers",
               where: t.label == ^label,
               select: %{label: t.label, name: t.name, gym_badge: t.gym_badge}
           ) do
      pokemon =
        Repo.all(
          from p in "trainer_pokemon",
            where: p.trainer_label == ^label,
            order_by: p.slot,
            select: %{species: p.species, level: p.level, moves: p.moves}
        )

      Map.put(trainer, :pokemon, pokemon)
    end
  end

  @doc "Wild encounters of a species on every map, highest rate first."
  def encounters(species) do
    Repo.all(
      from e in "encounters",
        where: e.species == ^species,
        order_by: [e.map, e.method, desc: e.rate],
        select: %{
          map: e.map,
          method: e.method,
          rate: e.rate,
          min_level: e.min_level,
          max_level: e.max_level
        }
    )
  end

  @doc "A species with its Generation III types and evolutions, or nil."
  def species(name) do
    Repo.one(
      from s in "species",
        where: s.name == ^name,
        select: %{name: s.name, types: s.types, evolutions: s.evolutions}
    )
  end

  @doc "The Generation III damage multiplier of an attacking type on a defending type."
  def multiplier(attacker, defender) do
    Repo.one(
      from m in "type_matchups",
        where: m.attacker == ^attacker and m.defender == ^defender,
        select: m.multiplier
    ) || 1.0
  end

  @doc "The Generation III type chart as `%{{attacker, defender} => multiplier}`; missing pairs are 1.0."
  def type_chart do
    Repo.all(from m in "type_matchups", select: {{m.attacker, m.defender}, m.multiplier})
    |> Map.new()
  end

  @doc "All hand-written locations."
  def locations, do: Repo.all(locations_query())

  @doc "A location by name, or nil when unlisted (which the Spoiler horizon treats as not allowed)."
  def location(name), do: Repo.one(from l in locations_query(), where: l.name == ^name)

  defp locations_query,
    do:
      from(l in "locations",
        select: %{name: l.name, map: l.map, badges_required: l.badges_required}
      )

  @doc "The player's Progress."
  def progress do
    Repo.one(
      from p in "progress",
        where: p.id == 1,
        select: %{badges: p.badges, team: p.team, location: p.location, humor: p.humor}
    )
  end
end
