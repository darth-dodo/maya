defmodule Maya.GameData do
  @moduledoc """
  Maya's game Facts and each guest's Progress in Postgres, loaded only from committed files:
  game data from `priv/data/*.json` by `import!/0`, and a guest's Progress seeded from
  `priv/progress.json` on first use (ADR-008). No network.
  """

  import Ecto.Query

  alias Maya.Repo
  alias Maya.Voice.Vocabulary

  # Children before parents, so deletes never trip the trainer_pokemon foreign key.
  @game_tables ~w(trainer_pokemon trainers encounters type_matchups species locations learnsets)

  @doc """
  Replaces the game data tables from `priv/data/` in one transaction. Progress is
  never touched: each guest seeds their own on first use (`progress/1`).
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
        insert!("learnsets", data.("learnsets"), ~w(species move method level))
      end)

    # Bias names are cached from these tables.
    Vocabulary.refresh()
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

  @doc "A species' Emerald moves (`move`, `level`, `method`) in level order, then file order."
  def learnset(species) do
    Repo.all(
      from l in "learnsets",
        where: l.species == ^species,
        order_by: [l.level, l.id],
        select: %{move: l.move, level: l.level, method: l.method}
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

  @doc "Every species name (PokeAPI form, `ralts`)."
  def species_names, do: Repo.all(from s in "species", select: s.name)

  @doc "All hand-written locations."
  def locations, do: Repo.all(locations_query())

  @doc "A location by name, or nil when unlisted (which the Spoiler horizon treats as not allowed)."
  def location(name), do: Repo.one(from l in locations_query(), where: l.name == ^name)

  defp locations_query,
    do:
      from(l in "locations",
        select: %{name: l.name, map: l.map, badges_required: l.badges_required}
      )

  @doc """
  A guest's Progress, seeded from `priv/progress.json` on the first read. Racing first reads
  end with one row: the insert does nothing on the guest's unique index.
  """
  def progress(guest_id) when is_binary(guest_id) do
    query = progress_query(guest_id)

    case Repo.one(query) do
      nil ->
        seed_progress!(guest_id)
        Repo.one!(query)

      progress ->
        progress
    end
  end

  @doc "A seeded guest's Progress row, locked `FOR UPDATE` until the transaction ends."
  def lock_progress!(guest_id),
    do: Repo.one!(from p in progress_query(guest_id), lock: "FOR UPDATE")

  @doc "Writes badges, Team, PC box and location back to the guest's Progress row (Events only, ADR-006)."
  def put_progress!(%{guest_id: guest_id} = progress) do
    {1, _} =
      Repo.update_all(from(p in "progress", where: p.guest_id == ^guest_id),
        set: [
          badges: progress.badges,
          team: progress.team,
          box: progress.box,
          location: progress.location,
          updated_at: DateTime.utc_now(:second)
        ]
      )

    :ok
  end

  defp progress_query(guest_id) do
    from p in "progress",
      where: p.guest_id == ^guest_id,
      select: %{
        guest_id: p.guest_id,
        badges: p.badges,
        team: p.team,
        box: p.box,
        location: p.location,
        humor: p.humor
      }
  end

  defp seed_progress!(guest_id) do
    seed = Application.app_dir(:maya, "priv/progress.json") |> File.read!() |> Jason.decode!()
    now = DateTime.utc_now(:second)

    Repo.insert_all(
      "progress",
      [
        %{
          guest_id: guest_id,
          badges: seed["badges"],
          team: seed["team"],
          location: seed["location"],
          humor: seed["humor"],
          inserted_at: now,
          updated_at: now
        }
      ],
      on_conflict: :nothing,
      conflict_target: :guest_id
    )
  end
end
