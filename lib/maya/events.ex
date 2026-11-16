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

  @kinds ~w(badge_earned caught evolved level_up moved released undo)
  @team_max 6
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

  def change(progress, "released", %{"species" => name}, _data) when is_binary(name) do
    wanted = Facts.species_name(name)
    index = &Enum.find_index(&1, fn member -> member["species"] == wanted end)

    cond do
      i = index.(progress.team) ->
        {:ok, %{progress | team: List.delete_at(progress.team, i)},
         "#{say(wanted)} released from the Team."}

      i = index.(progress.box) ->
        {:ok, %{progress | box: List.delete_at(progress.box, i)},
         "#{say(wanted)} released from the PC."}

      true ->
        {:refused, "I can only release a Pokémon on your Team or in the PC."}
    end
  end

  def change(progress, "level_up", %{"species" => name, "level" => level}, _data)
      when is_binary(name) do
    with {:ok, index} <- on_team(progress.team, name),
         :ok <- level(level) do
      team = List.update_at(progress.team, index, &Map.put(&1, "level", level))
      {:ok, %{progress | team: team}, "#{say(Facts.species_name(name))} level #{level} logged."}
    end
  end

  def change(progress, "evolved", %{"from" => from, "to" => to}, data)
      when is_binary(from) and is_binary(to) do
    with {:ok, index} <- on_team(progress.team, from),
         {:ok, from_species} <- species(from, data),
         {:ok, to_species} <- species(to, data),
         :ok <- evolves(from_species, to_species) do
      team = List.update_at(progress.team, index, &Map.put(&1, "species", to_species.name))

      {:ok, %{progress | team: team},
       "#{say(to_species.name)} logged, evolved from #{say(from_species.name)}."}
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

  def change(_progress, kind, _details, _data) when kind in @kinds,
    do: {:refused, "Not sure what to log there, so nothing changed."}

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
    # Only a catch adds to Progress, so only a catch can repeat (other kinds skip the read).
    if kind == "caught" and repeat?(current, details, recent_catches(current.guest_id)) do
      name = say(Facts.species_name(details["species"]))
      {:ok, current, "#{name} level #{details["level"]} is already logged."}
    else
      data = %{species: &GameData.species/1, locations: GameData.locations()}
      apply_event(kind, current, details, data)
    end
  end

  defp recent_catches(guest_id) do
    since = DateTime.add(DateTime.utc_now(:second), -@repeat_seconds)

    Repo.all(
      from e in "events",
        where: e.guest_id == ^guest_id and e.kind == "caught" and e.inserted_at >= ^since,
        select: %{details: e.details}
    )
  end

  defp apply_event(kind, current, details, data) do
    with {:ok, progress, line} <- change(current, kind, details, data) do
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
end
