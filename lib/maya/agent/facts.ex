defmodule Maya.Agent.Facts do
  @moduledoc """
  The pure core of the agent's tools (ARCHITECTURE.md "Functional programming"): plain data
  in, `{:ok, fact}`, `{:error, :not_found}` or `{:error, :past_horizon}` out. The Spoiler
  horizon is applied here, before anything reaches the model (ADR-004).
  """

  alias Maya.Horizon

  @doc "A gym from `Horizon.gyms/0` by leader name (any case, trailing \"'s\" allowed), or nil."
  def gym(leader) do
    name = leader |> String.trim() |> String.downcase() |> String.replace_suffix("'s", "")
    Enum.find(Horizon.gyms(), &(String.downcase(&1.leader) == name))
  end

  @doc """
  The leader's team, her ace (highest level, last on a tie) and the player's Team rated by
  the best Gen 3 type multiplier against the ace. `types` maps species to types, `chart`
  maps `{attacker, defender}` to a multiplier (missing means 1.0).
  """
  def gym_counter(nil, _trainer, _progress, _types, _chart), do: {:error, :not_found}
  def gym_counter(_gym, nil, _progress, _types, _chart), do: {:error, :not_found}

  def gym_counter(gym, trainer, progress, types, chart) do
    if inside?(gym, progress) do
      leader_team =
        for p <- trainer.pokemon,
            do: %{
              species: p.species,
              level: p.level,
              types: types[p.species] || [],
              moves: p.moves
            }

      ace = leader_team |> Enum.reverse() |> Enum.max_by(& &1.level)

      # shortcut: rates types, not moves (Progress has no moves); upgrade when the Team has moves.
      team =
        for %{"species" => s, "level" => l} <- progress.team do
          member_types = types[s] || []

          %{
            species: s,
            level: l,
            types: member_types,
            vs_ace: best(member_types, ace.types, chart)
          }
        end

      lead = if team != [], do: Enum.max_by(team, &{&1.vs_ace, &1.level}).species

      {:ok,
       %{
         leader: gym.leader,
         badge: gym.badge,
         leader_team: leader_team,
         ace: Map.delete(ace, :moves),
         team: team,
         suggested_lead: lead
       }}
    else
      {:error, :past_horizon}
    end
  end

  defp inside?(gym, progress) do
    case Horizon.next_gym(progress) do
      nil -> true
      next -> gym.badge <= next.badge
    end
  end

  defp best([], _defender, _chart), do: 1.0

  defp best(attacker_types, defender_types, chart) do
    attacker_types
    |> Enum.map(fn a ->
      Enum.reduce(defender_types, 1.0, &(&2 * Map.get(chart, {a, &1}, 1.0)))
    end)
    |> Enum.max()
  end

  @doc """
  Types, evolutions and wild places inside the horizon. A species with no wild place inside the
  horizon (seen only past it, or a gift, legendary or fossil with no wild places) is
  `past_horizon` unless it is on the Team: a Team member is a Fact, with no places if none.
  """
  def find_pokemon(nil, _encounters, _locations, _progress), do: {:error, :not_found}

  def find_pokemon(species, encounters, locations, progress) do
    places = places(encounters, locations, progress)

    if meetable?(species.name, places, progress) do
      {:ok,
       %{name: species.name, types: species.types, evolutions: species.evolutions, places: places}}
    else
      {:error, :past_horizon}
    end
  end

  @doc "A species' wild places inside the horizon, from its encounters and the locations."
  def places(encounters, locations, progress) do
    by_map = Map.new(locations, &{&1.map, &1})

    for e <- encounters, Horizon.allowed?(by_map[e.map], progress) do
      %{
        location: by_map[e.map].name,
        method: e.method,
        rate: e.rate,
        min_level: e.min_level,
        max_level: e.max_level
      }
    end
  end

  # The one species rule for every tool: a wild place inside the horizon, or on the Team.
  defp meetable?(name, places, progress),
    do: places != [] or Enum.any?(progress.team, &(&1["species"] == name))

  @doc """
  A species' level-up moves at or below the level horizon (`Horizon.level_cap/2`), in level
  order. The species must be meetable inside the horizon, as for `find_pokemon/4`; `places`
  comes from `places/3`. No move above the level horizon is returned.
  """
  def move_learnset(nil, _learnset, _places, _progress, _ace_level), do: {:error, :not_found}

  def move_learnset(species, learnset, places, progress, ace_level) do
    if meetable?(species.name, places, progress) do
      cap = Horizon.level_cap(progress, ace_level)

      {:ok,
       %{
         name: species.name,
         level_horizon: cap,
         moves: for(m <- learnset, is_nil(cap) or m.level <= cap, do: m)
       }}
    else
      {:error, :past_horizon}
    end
  end

  @doc """
  A spoken place name as a listed location row, or nil: trimmed, any case, a leading "the"
  dropped, no fuzzy match (a mishearing fails closed).
  """
  def guide_location(name, locations) do
    wanted = name |> String.trim() |> String.downcase() |> String.replace(~r/^the\s+/, "")
    Enum.find(locations, &(String.downcase(&1.name) == wanted))
  end

  @doc """
  A location's Walkthrough note. Unlisted and past the horizon are both `past_horizon`, so a
  later place is never told apart from a made-up one; a listed place inside it with no note
  is `not_found`. `note` comes from a query already filtered on the badges earned.
  """
  def search_guide(location, note, progress) do
    cond do
      not Horizon.allowed?(location, progress) -> {:error, :past_horizon}
      is_nil(note) -> {:error, :not_found}
      true -> {:ok, %{location: location.name, note: note}}
    end
  end

  @doc "A spoken Pokémon name as a PokeAPI species name (`Mr Mime` is `mr-mime`)."
  def species_name(name),
    do: name |> String.trim() |> String.downcase() |> String.replace(~r/\s+/, "-")

  @doc "A hint inside the horizon for a past-horizon Question; it names a leader, never a place."
  def hint(progress) do
    case Horizon.next_gym(progress) do
      nil -> "Every badge is earned, so train the Team for what comes next."
      next -> "Focus on earning #{next.leader}'s badge first."
    end
  end
end
