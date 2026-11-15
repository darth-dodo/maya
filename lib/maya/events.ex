defmodule Maya.Events do
  @moduledoc """
  Events: what the Guest tells Maya about their game, written with the Progress it produces
  (ADR-006). `change/4` is pure and validates against Maya's own data (ADR-004); `log/3`
  writes the Event and the Progress in one transaction, and `undo` restores the snapshot the
  Guest's last Event kept. Lines name only what the Guest said and the data confirms.
  """

  import Ecto.Query

  alias Maya.Agent.Facts
  alias Maya.{GameData, Horizon, Repo}

  @kinds ~w(badge_earned caught evolved level_up moved undo)
  @team_max 6

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
         :ok <- level(level),
         :ok <- room(progress.team) do
      member = %{"species" => species.name, "level" => level}

      {:ok, %{progress | team: progress.team ++ [member]},
       "#{say(species.name)} level #{level} logged on the Team."}
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

  defp room(team) when length(team) < @team_max, do: :ok
  defp room(_team), do: {:refused, "The Team is full at 6, so I left it as is."}

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
            location: previous["location"]
        }

        GameData.put_progress!(progress)
        {:ok, progress, "Undone, that Event is off the record."}
    end
  end

  defp run(kind, current, details) do
    data = %{species: &GameData.species/1, locations: GameData.locations()}

    with {:ok, progress, line} <- change(current, kind, details, data) do
      Repo.insert_all("events", [
        %{
          guest_id: current.guest_id,
          kind: kind,
          details: details,
          previous: Map.take(current, [:badges, :team, :location]),
          inserted_at: DateTime.utc_now(:second)
        }
      ])

      GameData.put_progress!(progress)
      {:ok, progress, line}
    end
  end
end
