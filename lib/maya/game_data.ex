defmodule Maya.GameData do
  @moduledoc """
  Maya's game Facts and each guest's Progress in Postgres, loaded only from committed files:
  game data from `priv/data/*.json` by `import!/0`, and a guest's Progress seeded from
  `priv/progress.json` on first use (ADR-008). No network.
  """

  import Ecto.Query

  alias Maya.GameData.Notes
  alias Maya.GameData.Places
  alias Maya.Repo
  alias Maya.Voice.Vocabulary

  # Children before parents, so deletes never trip the trainer_pokemon foreign key.
  @game_tables ~w(trainer_places item_places items trainer_pokemon trainers encounters type_matchups species locations learnsets walkthrough_notes)

  @doc """
  Replaces the game data tables from `priv/data/` in one transaction. Progress is
  never touched: each guest seeds their own on first use (`progress/1`).
  """
  def import!(priv \\ Application.app_dir(:maya, "priv")) do
    data = fn file ->
      priv |> Path.join("data/#{file}.json") |> File.read!() |> Jason.decode!()
    end

    trainers = data.("trainers")
    locations = data.("locations")
    notes = data.("walkthrough_notes")

    # Checked before the transaction, so a bad notes file changes no table (fail closed).
    case Notes.problems(notes, locations) do
      [] -> :ok
      problems -> raise ArgumentError, "walkthrough notes: #{inspect(problems)}"
    end

    places = %{
      locations: locations,
      trainers: trainers,
      interiors: data.("interiors"),
      gifts: data.("gifts"),
      items: data.("items"),
      trainer_places: data.("trainer_places"),
      item_places: data.("item_places"),
      access: data.("access")
    }

    case Places.problems(places) do
      [] -> :ok
      problems -> raise ArgumentError, "trainer and item places: #{inspect(problems)}"
    end

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

        insert!("locations", locations, ~w(name map badges_required))
        insert!("learnsets", data.("learnsets"), ~w(species move method level))
        insert!("walkthrough_notes", notes, ~w(location badges_required text))
        insert!("items", Enum.map(places.items, &%{"name" => &1}), ~w(name))

        insert!(
          "trainer_places",
          Places.trainer_rows(places),
          ~w(map location badges_required trainer_label name)
        )

        insert!(
          "item_places",
          Places.item_rows(places),
          ~w(item map location how badges_required)
        )
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

  @doc """
  The trainers told under a listed location, in file order, each with its party `label`,
  `badges_required` and its first party (`species`, `level`) in slot order.
  """
  def trainers_at(location) do
    trainers =
      Repo.all(
        from t in "trainer_places",
          where: t.location == ^location,
          order_by: t.id,
          select: %{label: t.trainer_label, name: t.name, badges_required: t.badges_required}
      )

    labels = Enum.map(trainers, & &1.label)

    parties =
      Repo.all(
        from p in "trainer_pokemon",
          where: p.trainer_label in ^labels,
          order_by: [p.trainer_label, p.slot],
          select: {p.trainer_label, %{species: p.species, level: p.level}}
      )
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    for t <- trainers, do: Map.put(t, :pokemon, parties[t.label] || [])
  end

  @doc "Every item name (`mach bike`, `hm05 flash`)."
  def item_names, do: Repo.all(from i in "items", select: i.name)

  @doc "Where an item is found, hidden, sold or given: `location`, `how`, `badges_required`."
  def item_places(item) do
    Repo.all(
      from p in "item_places",
        where: p.item == ^item,
        order_by: [p.badges_required, p.id],
        select: %{location: p.location, how: p.how, badges_required: p.badges_required}
    )
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

  @doc "A location's Walkthrough note text, or nil when it has none inside `badges` earned."
  def walkthrough_note(location, badges) do
    Repo.one(
      from n in "walkthrough_notes",
        where: n.location == ^location and n.badges_required <= ^badges,
        select: n.text,
        limit: 1
    )
  end

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

  @doc "Writes one guest's Humor dial (0 to 100), the only Dial set by voice (`set_setting`)."
  def put_humor!(guest_id, humor) when is_binary(guest_id) and humor in 0..100 do
    {1, _} =
      Repo.update_all(from(p in "progress", where: p.guest_id == ^guest_id),
        set: [humor: humor, updated_at: DateTime.utc_now(:second)]
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
