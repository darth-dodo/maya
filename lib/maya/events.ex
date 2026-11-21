defmodule Maya.Events do
  @moduledoc """
  Events: what the Guest tells Maya about their game, written with the Progress it produces
  (ADR-006). `change/4` is pure over the lookups it is given and validates against Maya's own data (ADR-004); `log/3`
  writes the Event and the Progress in one transaction, and `undo` restores the snapshot the
  Guest's last Event kept. Lines name only what the Guest said and the data confirms.
  """

  import Ecto.Query

  alias Maya.Agent.Facts
  alias Maya.{GameData, Horizon, Repo}

  @kinds ~w(badge_earned caught evolved level_up moved released deposited withdrawn set_lead set_team set_level undo)
  # Team changes that can leave Progress as it was; then no Event is written (team-voice).
  @team_kinds ~w(set_lead set_team set_level)
  @team_max 6
  @needs %{
    "caught" => "To log a catch I need the Pokémon and its level.",
    "evolved" => "To log an evolution I need the Pokémon it evolved from and into.",
    "level_up" => "To log a level I need the Pokémon and its level.",
    "set_level" => "To log a level I need the Pokémon and its level.",
    "moved" => "To log a place I need its name.",
    "released" => "To release a Pokémon I need to know which one.",
    "deposited" => "To deposit a Pokémon I need to know which one.",
    "withdrawn" => "To withdraw a Pokémon I need to know which one.",
    "set_lead" => "To set a lead I need to know which Pokémon."
  }
  @stale {:refused, "That Pokémon moved, so nothing changed."}
  # A catch repeated this soon is the agent logging it again, not a second catch (#116).
  # shortcut: a real identical second catch inside the window is not logged; upgrade to a
  # per-turn key if Guests hit it.
  @repeat_seconds 120

  def kinds, do: @kinds

  @doc """
  Progress after one Event, as `{:ok, progress, confirm}` or `{:refused, line}`. `data` has
  `species` (a name to a species map with `evolutions`, or nil) and `locations` (the rows).
  """
  def change(progress, "badge_earned", details, _data) do
    next = Horizon.next_gym(progress)
    gym = badge_gym(details)

    cond do
      next == nil -> {:refused, "Every badge is already logged."}
      gym && gym.badge < next.badge -> {:refused, "You already have the #{gym.badge_name}."}
      # A later, unknown or missing gym gets the same line, so no later gym is confirmed.
      gym != next -> {:refused, "I can only log #{next.leader}'s badge next."}
      true -> {:ok, %{progress | badges: progress.badges ++ [next.badge]}, badge_line(next)}
    end
  end

  def change(progress, "caught", %{"species" => name, "level" => level}, data)
      when is_binary(name) do
    with {:ok, species} <- species(name, data),
         :ok <- level(level) do
      member = %{"species" => species.name, "level" => level}

      # As in Emerald, a catch with a full Team goes to the PC box.
      if length(progress.team) < @team_max do
        {:ok, %{progress | team: progress.team ++ [member]},
         "#{say(species.name)} level #{level} logged on the Team."}
      else
        {:ok, %{progress | box: progress.box ++ [member]},
         "#{say(species.name)} level #{level} sent to the PC, the Team is full at #{@team_max}."}
      end
    end
  end

  def change(progress, "released", %{"species" => name} = details, _data) when is_binary(name) do
    wanted = Facts.species_name(name)

    case {pick(progress.team, wanted, details), box_pick(progress.box, wanted, details)} do
      {:stale, _} ->
        @stale

      {i, _} when is_integer(i) ->
        {:ok, %{progress | team: List.delete_at(progress.team, i)},
         "#{say(wanted)} released from the Team."}

      {nil, i} when is_integer(i) ->
        {:ok, %{progress | box: List.delete_at(progress.box, i)},
         "#{say(wanted)} released from the PC."}

      _none ->
        {:refused, "I can only release a Pokémon on your Team or in the PC."}
    end
  end

  def change(progress, "deposited", %{"species" => name} = details, _data) when is_binary(name) do
    wanted = Facts.species_name(name)

    case pick(progress.team, wanted, details) do
      :stale ->
        @stale

      nil ->
        {:refused, "I can only deposit a Pokémon on your Team."}

      _i when length(progress.team) == 1 ->
        {:refused, "Your Team needs at least one Pokémon."}

      i ->
        {member, team} = List.pop_at(progress.team, i)

        {:ok, %{progress | team: team, box: progress.box ++ [member]},
         "#{say(wanted)} sent to the PC."}
    end
  end

  def change(progress, "withdrawn", %{"species" => name} = details, _data) when is_binary(name) do
    wanted = Facts.species_name(name)

    case pick(progress.box, wanted, details) do
      :stale ->
        @stale

      nil ->
        {:refused, "I can only withdraw a Pokémon in the PC."}

      _i when length(progress.team) >= @team_max ->
        # The lowest level member, ties to the last in Team order (Abhishek, 2026-11-16).
        lowest = progress.team |> Enum.reverse() |> Enum.min_by(& &1["level"])

        {:refused,
         "The Team is full at #{@team_max}. Deposit one first, maybe #{say(lowest["species"])}."}

      i ->
        {member, box} = List.pop_at(progress.box, i)

        {:ok, %{progress | team: progress.team ++ [member], box: box},
         "#{say(wanted)} level #{member["level"]} joined the Team."}
    end
  end

  def change(progress, "set_lead", %{"species" => name} = details, _data) when is_binary(name) do
    wanted = Facts.species_name(name)

    case pick(progress.team, wanted, details) do
      :stale ->
        @stale

      0 ->
        {:ok, progress, "#{say(wanted)} already leads the Team."}

      nil ->
        if pick(progress.box, wanted),
          do: {:refused, "#{say(wanted)} is in the PC, withdraw it first."},
          else: {:refused, "Only a Pokémon on your Team can lead."}

      i ->
        {member, rest} = List.pop_at(progress.team, i)
        {:ok, %{progress | team: [member | rest]}, "#{say(wanted)} leads the Team now."}
    end
  end

  def change(progress, "set_level", %{"species" => name, "level" => level} = details, _data)
      when is_binary(name) do
    wanted = Facts.species_name(name)

    with :ok <- level(level) do
      case {pick(progress.team, wanted, details), box_pick(progress.box, wanted, details)} do
        {:stale, _} -> @stale
        {i, _} when is_integer(i) -> set_level(progress, :team, i, level)
        {nil, i} when is_integer(i) -> set_level(progress, :box, i, level)
        _none -> {:refused, "I can only set a level for a Pokémon on your Team or in the PC."}
      end
    end
  end

  def change(progress, "set_team", %{"team" => named}, data)
      when is_list(named) and length(named) in 1..@team_max do
    named
    |> Enum.reduce_while({[], progress.team, progress.box}, fn entry, {team, left, box} ->
      case take(entry, left, box, data) do
        {:ok, member, left, box} -> {:cont, {[member | team], left, box}}
        refused -> {:halt, refused}
      end
    end)
    |> case do
      {team, left, box} ->
        team = Enum.reverse(team)
        new = %{progress | team: team, box: box ++ left}
        list = Enum.map_join(team, ", ", &"#{say(&1["species"])} level #{&1["level"]}")
        sent = if left == [], do: "", else: " #{length(left)} sent to the PC."

        if new == progress,
          do: {:ok, progress, "That is already your Team."},
          else: {:ok, new, "Team set: #{list}.#{sent}"}

      refused ->
        refused
    end
  end

  def change(_progress, "set_team", _details, _data),
    do: {:refused, "A Team holds 1 to #{@team_max} Pokémon."}

  def change(progress, "level_up", %{"species" => name, "level" => level}, _data)
      when is_binary(name) do
    with {:ok, index} <- on_team(progress.team, name),
         :ok <- level(level) do
      team = List.update_at(progress.team, index, &Map.put(&1, "level", level))
      {:ok, %{progress | team: team}, "#{say(Facts.species_name(name))} level #{level} logged."}
    end
  end

  # "Lotad evolved into Lombre at 18" is one Event: an optional level is set with it (#225).
  def change(progress, "evolved", %{"from" => from, "to" => to} = details, data)
      when is_binary(from) and is_binary(to) do
    level = details["level"]

    with {:ok, index} <- on_team(progress.team, from),
         {:ok, from_species} <- species(from, data),
         {:ok, to_species} <- species(to, data),
         :ok <- evolves(from_species, to_species),
         :ok <- if(level == nil, do: :ok, else: level(level)) do
      team =
        List.update_at(
          progress.team,
          index,
          &%{&1 | "species" => to_species.name, "level" => level || &1["level"]}
        )

      at = if level, do: " level #{level}", else: ""

      {:ok, %{progress | team: team},
       "#{say(to_species.name)}#{at} logged, evolved from #{say(from_species.name)}."}
    end
  end

  def change(progress, "moved", %{"location" => name}, data) when is_binary(name) do
    wanted = name |> String.trim() |> String.downcase()
    location = Enum.find(data.locations, &(String.downcase(&1.name) == wanted))

    if Horizon.allowed?(location, progress) do
      {:ok, %{progress | location: location.name}, "Location logged: #{location.name}."}
    else
      {:refused, "I can only log places up to the Next gym."}
    end
  end

  # A known kind whose details do not fit says what that kind needs, so the next try can (#225).
  def change(_progress, kind, _details, _data) when kind in @kinds,
    do: {:refused, Map.get(@needs, kind, "Not sure what to log there, so nothing changed.")}

  def change(_progress, _kind, _details, _data),
    do: {:refused, "I can log badges, catches, evolutions, levels and places."}

  defp badge_gym(%{"badge" => n}) when is_integer(n),
    do: Enum.find(Horizon.gyms(), &(&1.badge == n))

  defp badge_gym(%{"leader" => leader}) when is_binary(leader), do: Facts.gym(leader)
  defp badge_gym(_details), do: nil

  defp badge_line(gym), do: "#{gym.badge_name} logged. Mudkip would approve."

  defp species(name, data) do
    case data.species.(Facts.species_name(name)) do
      nil -> {:refused, "That Pokémon is not in my data."}
      species -> {:ok, species}
    end
  end

  defp level(level) when is_integer(level) and level in 1..100, do: :ok
  defp level(_level), do: {:refused, "Levels go from 1 to 100."}

  defp on_team(team, name) do
    case Enum.find_index(team, &(&1["species"] == Facts.species_name(name))) do
      nil -> {:refused, "I can only log that for a Pokémon on your Team."}
      index -> {:ok, index}
    end
  end

  # The index of the member to change: the 1-based `slot` the screen sent, checked against the
  # species so a stale screen changes nothing, else the first member of that species.
  defp pick(list, wanted, %{"slot" => slot}) do
    if is_integer(slot) and slot >= 1 and match?(%{"species" => ^wanted}, Enum.at(list, slot - 1)),
      do: slot - 1,
      else: :stale
  end

  defp pick(list, wanted, _details), do: pick(list, wanted)
  defp pick(list, wanted), do: Enum.find_index(list, &(&1["species"] == wanted))

  # A slot on these kinds names a Team position, so the PC box is searched only without one.
  defp box_pick(_box, _wanted, %{"slot" => _}), do: nil
  defp box_pick(box, wanted, _details), do: pick(box, wanted)

  defp set_level(progress, where, i, level) do
    member = Enum.at(Map.fetch!(progress, where), i)
    name = say(member["species"])

    if member["level"] == level do
      {:ok, progress, "#{name} is already level #{level}."}
    else
      list = List.replace_at(Map.fetch!(progress, where), i, %{member | "level" => level})
      {:ok, Map.put(progress, where, list), "#{name} is level #{level} now."}
    end
  end

  # One `set_team` member: taken from the Team members not yet named, then the PC box, else new.
  defp take(%{"species" => name} = entry, left, box, data) when is_binary(name) do
    level = entry["level"]

    with {:ok, species} <- species(name, data),
         :ok <- if(level == nil, do: :ok, else: level(level)) do
      wanted = species.name

      cond do
        i = pick(left, wanted) -> taken(List.pop_at(left, i), level, box, :left)
        i = pick(box, wanted) -> taken(List.pop_at(box, i), level, left, :box)
        level == nil -> {:refused, "What level is #{say(wanted)}?"}
        true -> {:ok, %{"species" => wanted, "level" => level}, left, box}
      end
    end
  end

  defp take(_entry, _left, _box, _data), do: {:refused, "That Pokémon is not in my data."}

  defp taken({member, rest}, level, other, from) do
    member = if level, do: %{member | "level" => level}, else: member
    if from == :left, do: {:ok, member, rest, other}, else: {:ok, member, other, rest}
  end

  defp evolves(from, to) do
    if Enum.any?(from.evolutions, &(&1["into"] == to.name)),
      do: :ok,
      else: {:refused, "Not sure that is how it evolves."}
  end

  @doc """
  Whether a catch repeats one in `recent` (the Guest's catches inside the window): same
  species and level, and that Pokémon is still on the Team or in the PC box, so a catch after
  a release still counts (#116).
  """
  def repeat?(progress, %{"species" => name, "level" => level}, recent) when is_binary(name) do
    member = %{"species" => Facts.species_name(name), "level" => level}

    member in (progress.team ++ progress.box) and
      Enum.any?(recent, fn %{details: details} ->
        is_binary(details["species"]) and details["level"] == level and
          Facts.species_name(details["species"]) == member["species"]
      end)
  end

  def repeat?(_progress, _details, _recent), do: false

  defp say(name), do: name |> String.split("-") |> Enum.map_join(" ", &String.capitalize/1)

  @doc """
  Writes one Event for the Guest whose Progress this is and returns `{:ok, confirm, progress}`
  or `{:refused, line}`. The Progress row is locked for the transaction, so two Events for one
  Guest cannot interleave. A refusal writes nothing.
  """
  def log(%{guest_id: guest_id}, kind, details) when is_map(details) do
    Repo.transaction(fn ->
      current = GameData.lock_progress!(guest_id)

      case run(kind, current, details) do
        {:ok, progress, line} -> {line, progress}
        {:refused, line} -> Repo.rollback(line)
      end
    end)
    |> case do
      {:ok, {line, progress}} -> {:ok, line, progress}
      {:error, line} -> {:refused, line}
    end
  end

  defp run("undo", current, _details) do
    last =
      Repo.one(
        from e in "events",
          where: e.guest_id == ^current.guest_id,
          order_by: [desc: e.id],
          limit: 1,
          select: %{id: e.id, previous: e.previous}
      )

    case last do
      nil ->
        {:refused, "There is nothing to undo."}

      %{id: id, previous: previous} ->
        Repo.delete_all(from e in "events", where: e.id == ^id)

        progress = %{
          current
          | badges: previous["badges"],
            team: previous["team"],
            # Events from before the PC box (#116) kept no box, so it stays as it is.
            box: Map.get(previous, "box", current.box),
            location: previous["location"]
        }

        GameData.put_progress!(progress)
        {:ok, progress, "Undone, that Event is off the record."}
    end
  end

  defp run(kind, current, details) do
    cond do
      kind == "caught" and repeat?(current, details, recent_catches(current.guest_id)) ->
        name = say(Facts.species_name(details["species"]))
        {:ok, current, "#{name} level #{details["level"]} is already logged."}

      kind in ~w(deposited withdrawn) and repeats_last?(current.guest_id, kind, details) ->
        name = say(Facts.species_name(details["species"]))
        where = if kind == "deposited", do: "in the PC", else: "on the Team"
        {:ok, current, "#{name} is already #{where}."}

      true ->
        data = %{species: &GameData.species/1, locations: GameData.locations()}
        apply_event(kind, current, details, data)
    end
  end

  # A deposit or withdraw changes Progress each time, so a doubled call is caught by the last
  # Event only (same kind, species and slot, inside the window); an undo deletes it, so a later
  # identical deposit still counts (team-voice).
  # shortcut: a real second deposit of the same species inside the window without a slot is not
  # logged; upgrade to a per-turn key if Guests hit it.
  defp repeats_last?(guest_id, kind, %{"species" => name} = details) when is_binary(name) do
    since = DateTime.add(DateTime.utc_now(:second), -@repeat_seconds)

    last =
      Repo.one(
        from e in "events",
          where: e.guest_id == ^guest_id,
          order_by: [desc: e.id],
          limit: 1,
          select: %{kind: e.kind, details: e.details, recent: e.inserted_at >= ^since}
      )

    match?(%{kind: ^kind, recent: true, details: %{"species" => s}} when is_binary(s), last) and
      Facts.species_name(last.details["species"]) == Facts.species_name(name) and
      last.details["slot"] == details["slot"]
  end

  defp repeats_last?(_guest_id, _kind, _details), do: false

  defp recent_catches(guest_id) do
    since = DateTime.add(DateTime.utc_now(:second), -@repeat_seconds)

    Repo.all(
      from e in "events",
        where: e.guest_id == ^guest_id and e.kind == "caught" and e.inserted_at >= ^since,
        select: %{details: e.details}
    )
  end

  defp apply_event(kind, current, details, data) do
    case change(current, kind, details, data) do
      {:ok, progress, line} when kind in @team_kinds and progress == current ->
        {:ok, current, line}

      {:ok, progress, line} ->
        write_event(kind, current, details, progress, line)

      refused ->
        refused
    end
  end

  defp write_event(kind, current, details, progress, line) do
    Repo.insert_all("events", [
      %{
        guest_id: current.guest_id,
        kind: kind,
        details: details,
        previous: Map.take(current, [:badges, :team, :box, :location]),
        inserted_at: DateTime.utc_now(:second)
      }
    ])

    GameData.put_progress!(progress)
    {:ok, progress, line}
  end
end
