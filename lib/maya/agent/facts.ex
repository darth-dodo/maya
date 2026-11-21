defmodule Maya.Agent.Facts do
  @moduledoc """
  The pure core of the agent's tools (ARCHITECTURE.md "Functional programming"): plain data
  in, `{:ok, fact}`, `{:error, :not_found}` or `{:error, :past_horizon}` out. The Spoiler
  horizon is applied here, before anything reaches the model (ADR-004).
  """

  alias Maya.Horizon

  # pokeemerald lists the rival once per rival and per starter (`MayRoute103Mudkip`).
  @rival ~r/^(May|Brendan)\w+(Treecko|Torchic|Mudkip)$/
  @starters %{
    "treecko" => ~w(treecko grovyle sceptile),
    "torchic" => ~w(torchic combusken blaziken),
    "mudkip" => ~w(mudkip marshtomp swampert)
  }

  @types ~w(normal fighting flying poison ground rock bug ghost steel fire water grass electric psychic ice dragon dark)

  # A member is ready at or above the ace's level, or 2x or better and at most this many below.
  @ready_gap 3

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

  @doc """
  The Team against the Next gym's ace only (`gym` is `Horizon.next_gym/1`, never a later one):
  each member's level gap to the ace and best type multiplier, and `ready`. With every badge
  `gym` is nil: a Fact with no Next gym and the hint.
  """
  def team_check(nil, _trainer, progress, _types, _chart),
    do: {:ok, %{next_gym: nil, hint: hint(progress)}}

  def team_check(gym, trainer, progress, types, chart) do
    with {:ok, fact} <- gym_counter(gym, trainer, progress, types, chart) do
      team =
        for m <- fact.team do
          gap = if is_integer(m.level), do: m.level - fact.ace.level
          %{species: m.species, level: m.level, level_gap: gap, vs_ace: m.vs_ace}
        end

      {:ok,
       %{
         leader: fact.leader,
         badge: fact.badge,
         ace: fact.ace,
         team: team,
         ready: Enum.any?(team, &ready?/1)
       }}
    end
  end

  defp ready?(%{level_gap: gap}) when not is_integer(gap), do: false
  defp ready?(%{level_gap: gap, vs_ace: vs}), do: gap >= 0 or (vs >= 2.0 and gap >= -@ready_gap)

  defp inside?(gym, progress) do
    case Horizon.next_gym(progress) do
      nil -> true
      next -> gym.badge <= next.badge
    end
  end

  defp best([], _defender, _chart), do: 1.0

  defp best(attacker_types, defender_types, chart),
    do: attacker_types |> Enum.map(&product(&1, defender_types, chart)) |> Enum.max()

  # An attacking type on one or two defending types: the chart multipliers multiplied.
  defp product(attacker, defender_types, chart),
    do: Enum.reduce(defender_types, 1.0, &(&2 * Map.get(chart, {attacker, &1}, 1.0)))

  @doc "The 17 Generation III types (no Fairy in Emerald)."
  def types, do: @types

  @doc """
  The gyms inside the Spoiler horizon: every gym up to the Next gym, or all with every badge.
  Their leaders' parties are Pokémon the player meets inside the horizon.
  """
  def gyms_inside(progress), do: Enum.filter(Horizon.gyms(), &inside?(&1, progress))

  @doc """
  Type multipliers on a defender from the chart, with the reason lines that exist (`reasons`
  maps `{attacker, defender}` to a line). `defender` is `{:type, name}`, `{:gym, gym, trainer,
  types}` (the leader's ace) or `{:species, species, places, met}` with `places` from
  `places/3` and `met` the species in the parties of `gyms_inside/1`; nil is `not_found`.
  With an `attacker` type, its multiplier; without, the types at 2 or more (`good`) and below 1
  (`avoid`), strongest first.
  """
  def type_matchup(attacker, defender, chart, reasons, progress) do
    attacker = attacker && attacker |> String.trim() |> String.downcase()

    if is_nil(defender) or (attacker && attacker not in @types) do
      {:error, :not_found}
    else
      with {:ok, d} <- defending(defender, progress), do: {:ok, rate(attacker, d, chart, reasons)}
    end
  end

  defp defending({:type, type}, _progress), do: {:ok, %{name: type, types: [type]}}

  defp defending({:gym, gym, trainer, types}, progress) do
    cond do
      not inside?(gym, progress) -> {:error, :past_horizon}
      is_nil(trainer) -> {:error, :not_found}
      true -> {:ok, ace(gym, trainer, types)}
    end
  end

  defp defending({:species, species, places, met}, progress) do
    if meetable?(species.name, places, progress) or species.name in met,
      do: {:ok, %{name: species.name, types: species.types}},
      else: {:error, :past_horizon}
  end

  # The ace is the highest level, last on a tie, as for `gym_counter/5`.
  defp ace(gym, trainer, types) do
    ace = trainer.pokemon |> Enum.reverse() |> Enum.max_by(& &1.level)
    %{leader: gym.leader, name: ace.species, types: types[ace.species] || []}
  end

  defp rate(nil, d, chart, reasons) do
    rows =
      for a <- @types,
          m = product(a, d.types, chart),
          m != 1.0,
          do: %{type: a, multiplier: m, reasons: reasons(a, d.types, reasons)}

    %{
      defender: d,
      good: rows |> Enum.filter(&(&1.multiplier >= 2)) |> Enum.sort_by(& &1.multiplier, :desc),
      avoid: rows |> Enum.filter(&(&1.multiplier < 1)) |> Enum.sort_by(& &1.multiplier)
    }
  end

  defp rate(attacker, d, chart, reasons) do
    %{
      defender: d,
      attacker: attacker,
      multiplier: product(attacker, d.types, chart),
      reasons: reasons(attacker, d.types, reasons)
    }
  end

  defp reasons(attacker, defender_types, reasons),
    do: for(t <- defender_types, line = reasons[{attacker, t}], do: line)

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

  @doc """
  The trainers on a listed location inside the horizon, each with its first party (species and
  levels). Unlisted and past the horizon are both `past_horizon`, as for `search_guide/3`; a
  trainer row past the horizon (a gym in a city inside it) is left out.
  """
  def find_trainer(location, trainers, progress) do
    if Horizon.allowed?(location, progress) do
      {rivals, others} =
        trainers
        |> Enum.filter(&Horizon.allowed?(&1, progress))
        |> Enum.split_with(&Regex.match?(@rival, &1[:label] || ""))

      {:ok,
       %{
         place: location.name,
         trainers: Enum.map(others, &Map.take(&1, [:name, :pokemon])) ++ rival(rivals, progress)
       }}
    else
      {:error, :past_horizon}
    end
  end

  defp rival([], _progress), do: []

  # Progress has no gender, so May and Brendan are one entry when their parties match.
  defp rival(rows, progress) do
    case starter(progress) do
      nil ->
        [%{name: "May or Brendan", note: "The rival's team depends on your starter."}]

      starter ->
        rows
        |> Enum.filter(&String.ends_with?(&1.label, String.capitalize(starter)))
        |> Enum.group_by(& &1.pokemon, & &1.name)
        # May before Brendan, as pokeemerald lists them.
        |> Enum.sort_by(fn {_party, names} -> names end, :desc)
        |> Enum.map(fn {party, names} ->
          %{name: names |> Enum.uniq() |> Enum.join(" or "), pokemon: party}
        end)
    end
  end

  @doc """
  The player's starter (`mudkip`): the one starter line in the Team or PC box. Nil when none or
  more than one is there, since no other starter can be caught inside the horizon.
  """
  def starter(progress) do
    owned = for %{"species" => s} <- progress.team ++ (progress[:box] || []), do: s

    case for {starter, line} <- @starters, Enum.any?(line, &(&1 in owned)), do: starter do
      [starter] -> starter
      _ -> nil
    end
  end

  @doc """
  Where to get an item inside the horizon, from its `item_places` rows: each place and how
  (`ball`, `hidden`, `mart` or `gift`). A known item with no place inside is `past_horizon`;
  `nil` (not an item name) is `not_found`.
  """
  def find_item(nil, _rows, _progress), do: {:error, :not_found}

  def find_item(item, rows, progress) do
    case for(
           r <- rows,
           Horizon.allowed?(r, progress),
           uniq: true,
           do: Map.take(r, [:location, :how])
         ) do
      [] -> {:error, :past_horizon}
      places -> {:ok, %{item: item, places: places}}
    end
  end

  @doc """
  A spoken item name as one of `names`, or nil: any case, accents and punctuation dropped
  (`Poké Ball` is `poke ball`, `S.S. Ticket` is `ss ticket`). A TM or HM matches by number,
  however it is heard (`HM05`, `HM 5`), or by move (`Flash`).
  """
  def item_name(spoken, names) do
    wanted =
      spoken
      |> String.downcase()
      |> :unicode.characters_to_nfd_binary()
      |> String.replace(~r/[\p{Mn}'’.]/u, "")
      |> String.replace(~r/[^a-z0-9]+/, " ")
      |> String.trim()
      |> String.replace(~r/^the /, "")
      |> String.replace(~r/^([th]m) ?(\d)\b/, "\\g{1}0\\2")
      |> String.replace(~r/^([th]m) (\d\d)\b/, "\\1\\2")

    Enum.find(names, &(&1 == wanted)) || Enum.find(names, &machine?(&1, wanted))
  end

  defp machine?(name, wanted) do
    case Regex.run(~r/^([th]m\d\d) (.+)$/, name) do
      [_, number, move] -> wanted in [number, move]
      nil -> false
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
