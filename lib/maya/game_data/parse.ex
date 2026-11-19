defmodule Maya.GameData.Parse do
  @moduledoc """
  Pure functions that turn pokeemerald sources and PokeAPI replies into the
  compact maps written to `priv/data/`. No IO: the fetch task does the HTTP.
  """

  alias Maya.Horizon

  @gen3_types ~w(normal fighting flying poison ground rock bug ghost steel fire water grass electric psychic ice dragon dark)
  @last_gen3_species 386
  @generations ~w(i ii iii iv v vi vii viii ix x)
  @party_block ~r/sParty_(\w+)\[\] = \{(.*?)\n\};/s
  @gym_badges Map.new(Horizon.gyms(), &{&1.party, &1})

  @doc "`SPECIES_NIDORAN_F` or `MOVE_ROCK_TOMB` to the PokeAPI name (`nidoran-f`, `rock-tomb`)."
  def constant_name(constant) do
    constant
    |> String.replace(~r/^(SPECIES|MOVE)_/, "")
    |> String.downcase()
    |> String.replace("_", "-")
  end

  @doc "Trainer parties from the text of `src/data/trainer_parties.h`."
  def parties(text) do
    for [_, label, body] <- Regex.scan(@party_block, text) do
      gym = @gym_badges[label]

      %{
        "label" => label,
        "name" =>
          if(gym,
            do: gym.leader,
            else: label |> String.replace(~r/\d+$/, "") |> String.replace("_", " ")
          ),
        "gym_badge" => gym && gym.badge,
        "pokemon" => body |> String.split(".iv =") |> tl() |> Enum.map(&party_mon/1)
      }
    end
  end

  defp party_mon(text) do
    [_, level] = Regex.run(~r/\.lvl = (\d+)/, text)
    [_, species] = Regex.run(~r/\.species = (SPECIES_\w+)/, text)

    moves =
      case Regex.run(~r/\.moves = \{([^}]*)\}/, text) do
        [_, list] -> list |> String.split(",", trim: true) |> Enum.map(&String.trim/1)
        nil -> []
      end

    %{
      "species" => constant_name(species),
      "level" => String.to_integer(level),
      "moves" => for(m <- moves, m != "MOVE_NONE", do: constant_name(m))
    }
  end

  @doc """
  Wild encounters from the decoded `wild_encounters.json`: one row per map,
  method and species, with the rate summed over its slots. Only the main
  game headers (`gWildMonHeaders`) are kept, and only the first header of a
  map (Altering Cave lists 9; the game uses the first).
  """
  def encounters(%{"wild_encounter_groups" => groups}) do
    %{"fields" => fields, "encounters" => encounters} =
      Enum.find(groups, &(&1["label"] == "gWildMonHeaders"))

    fields = Map.new(fields, &{&1["type"], &1})

    encounters
    |> Enum.uniq_by(& &1["map"])
    |> Enum.flat_map(fn enc -> Enum.flat_map(fields, &slots(enc, &1)) end)
    |> Enum.group_by(&{&1["map"], &1["method"], &1["species"]})
    |> Enum.map(fn {{map, method, species}, slots} ->
      %{
        "map" => map,
        "method" => method,
        "species" => species,
        "rate" => slots |> Enum.map(& &1["rate"]) |> Enum.sum(),
        "min_level" => slots |> Enum.map(& &1["min_level"]) |> Enum.min(),
        "max_level" => slots |> Enum.map(& &1["max_level"]) |> Enum.max()
      }
    end)
    |> Enum.sort_by(&{&1["map"], &1["method"], -&1["rate"], &1["species"]})
  end

  defp slots(encounter, {type, field}) do
    case encounter[type] do
      %{"mons" => mons} ->
        rod = rod_by_slot(field)

        mons
        |> Enum.with_index()
        |> Enum.map(fn {mon, i} ->
          %{
            "map" => encounter["map"],
            "method" => rod[i] || String.replace_suffix(type, "_mons", ""),
            "species" => constant_name(mon["species"]),
            "rate" => Enum.at(field["encounter_rates"], i),
            "min_level" => mon["min_level"],
            "max_level" => mon["max_level"]
          }
        end)

      nil ->
        []
    end
  end

  defp rod_by_slot(%{"groups" => groups}),
    do: for({rod, idx} <- groups, i <- idx, into: %{}, do: {i, rod})

  defp rod_by_slot(_field), do: %{}

  @doc "A PokeAPI `pokemon` reply's types as of Generation III."
  def gen3_types(pokemon) do
    pokemon["past_types"]
    |> as_of_gen3("types", pokemon["types"])
    |> Enum.sort_by(& &1["slot"])
    |> Enum.map(& &1["type"]["name"])
  end

  @doc """
  A PokeAPI `pokemon` reply's Emerald level-up moves as rows, in level order (PokeAPI's own
  order on a tie). Other version groups and methods (machine, egg, tutor) are left out.
  """
  def learnset(species, pokemon) do
    for %{"move" => %{"name" => move}, "version_group_details" => details} <- pokemon["moves"],
        %{
          "version_group" => %{"name" => "emerald"},
          "move_learn_method" => %{"name" => "level-up" = method},
          "level_learned_at" => level
        } <- details do
      %{"species" => species, "move" => move, "method" => method, "level" => level}
    end
    |> Enum.sort_by(& &1["level"])
  end

  @doc "A PokeAPI `type` reply's attacking matchups as of Generation III, non-neutral only."
  def gen3_matchups(%{"name" => attacker} = type) when attacker in @gen3_types do
    relations =
      as_of_gen3(
        type["past_damage_relations"],
        "damage_relations",
        type["damage_relations"]
      )

    for {key, multiplier} <- [
          {"no_damage_to", 0.0},
          {"half_damage_to", 0.5},
          {"double_damage_to", 2.0}
        ],
        %{"name" => defender} <- relations[key] || [],
        defender in @gen3_types do
      %{"attacker" => attacker, "defender" => defender, "multiplier" => multiplier}
    end
  end

  def gen3_matchups(_type), do: []

  # A past entry holds the values used up to its generation; the earliest one at or after III applies.
  defp as_of_gen3(past, key, current) do
    (past || [])
    |> Enum.map(&{generation(&1), &1[key]})
    |> Enum.filter(fn {gen, _} -> gen >= 3 end)
    |> Enum.min_by(fn {gen, _} -> gen end, fn -> {nil, current} end)
    |> elem(1)
  end

  defp generation(%{"generation" => %{"name" => "generation-" <> roman}}),
    do: Enum.find_index(@generations, &(&1 == roman)) + 1

  @doc """
  A map constant as its `data/maps/` directory: `MAP_ROUTE102` is `Route102`,
  `MAP_GRANITE_CAVE_1F` is `GraniteCave_1F`, and an interior of `city` (a map constant)
  is the city's directory, `_`, then the rest (`RustboroCity_Mart`).
  """
  def map_dir(map, city \\ nil)

  def map_dir(map, city) when city in [nil, map],
    do: map |> String.replace_prefix("MAP_", "") |> camel()

  def map_dir(map, city),
    do: map_dir(city) <> "_" <> (map |> String.replace_prefix(city <> "_", "") |> camel())

  defp camel(name) do
    name
    |> String.split("_")
    |> Enum.map_join(fn
      <<digit, _::binary>> = word when digit in ?0..?9 -> "_" <> word
      word -> String.capitalize(word)
    end)
  end

  @doc "Trainer constants from `src/data/trainers.h` to `{party label, spoken name}`."
  def trainer_constants(text) do
    for chunk <- text |> String.split("[TRAINER_") |> tl(),
        [_, id] <- [Regex.run(~r/^(\w+)\] =/, chunk)],
        [_, name] <- [Regex.run(~r/\.trainerName = _\("([^"]*)"\)/, chunk)],
        [_, label] <- [Regex.run(~r/\.party = \w+\(sParty_(\w+)\)/, chunk)],
        into: %{},
        do:
          {"TRAINER_" <> id,
           {label, name |> String.split(" ") |> Enum.map_join(" ", &String.capitalize/1)}}
  end

  @doc """
  The trainer constants a map's `scripts.inc` battles, in file order. Map scripts name only a
  trainer's first party (`TRAINER_CALVIN_1`); rematches come from the Match Call table.
  """
  def trainer_battles(scripts) do
    ~r/^\s*trainerbattle_\w+ (TRAINER_\w+)/m
    |> Regex.scan(scripts, capture: :all_but_first)
    |> List.flatten()
    |> Enum.uniq()
  end

  @doc """
  The item constants of a map's first `pokemart` list. Later lists open behind story or badge
  flags (`OldaleTown_Mart_Pokemart_Expanded`), so they are left out (fail closed).
  """
  def pokemart(scripts) do
    case Regex.run(~r/^\s*pokemart (\w+)/m, scripts) do
      [_, label] ->
        [_, body] = Regex.run(~r/^#{label}:\s*\n(.*?)pokemartlistend/ms, scripts)
        ~r/\.2byte (ITEM_\w+)/ |> Regex.scan(body, capture: :all_but_first) |> List.flatten()

      nil ->
        []
    end
  end

  @doc "Item ball scripts from `data/scripts/item_ball_scripts.inc`, as `%{script => item}`."
  def ball_scripts(text) do
    for [script, item] <-
          Regex.scan(~r/^(\w+)::\s*\n\s*finditem (ITEM_\w+)/m, text, capture: :all_but_first),
        into: %{},
        do: {script, item}
  end

  @doc "A decoded `map.json`'s items as `{item constant, how}`: `ball` object events, `hidden` bg events."
  def map_items(map, balls) do
    for(%{"script" => s} <- map["object_events"] || [], item = balls[s], do: {item, "ball"}) ++
      for %{"type" => "hidden_item", "item" => item} <- map["bg_events"] || [],
          do: {item, "hidden"}
  end

  @doc """
  Item constants to Maya's item names from `include/constants/items.h` and
  `include/constants/tms_hms.h`: `ITEM_MACH_BIKE` is `mach bike`, and both `ITEM_HM05` and
  the script alias `ITEM_HM_FLASH` are `hm05 flash`. Unnamed slots (`ITEM_034`) are left out.
  """
  def item_constants(items_h, tms_hms_h) do
    [_, enum] = Regex.run(~r/enum \{(.*?)\};/s, items_h)

    plain =
      for [c] <- Regex.scan(~r/^\s*(ITEM_[A-Z]\w*),/m, enum, capture: :all_but_first),
          c != "ITEM_NONE",
          into: %{},
          do:
            {c,
             c
             |> String.replace_prefix("ITEM_", "")
             |> String.downcase()
             |> String.replace("_", " ")}

    machines =
      for kind <- ["TM", "HM"],
          {move, i} <- tms_hms_h |> machine_moves(kind) |> Enum.with_index(1),
          number = kind <> String.pad_leading("#{i}", 2, "0"),
          name = String.downcase("#{number} #{String.replace(move, "_", " ")}"),
          constant <- ["ITEM_" <> number, "ITEM_#{kind}_#{move}"],
          into: %{},
          do: {constant, name}

    Map.merge(plain, machines)
  end

  defp machine_moves(text, kind) do
    [_, body] = Regex.run(~r/#define FOREACH_#{kind}\(F\)(.*?)\n\s*\n/s, text)
    ~r/F\((\w+)\)/ |> Regex.scan(body, capture: :all_but_first) |> List.flatten()
  end

  @doc "Whether a map's `scripts.inc` gives one of the item constants with `giveitem`."
  def gives?(scripts, constants),
    do: Enum.any?(constants, &Regex.match?(~r/giveitem #{&1}\b/, scripts))

  @doc "Metatile behavior names from `include/constants/metatile_behaviors.h`, as a tuple by value."
  def behaviors(text) do
    [_, enum] = Regex.run(~r/enum \{(.*?)\};/s, text)

    ~r/^\s*(MB_\w+)/m
    |> Regex.scan(enum, capture: :all_but_first)
    |> List.flatten()
    |> List.to_tuple()
  end

  @doc "Metatile attribute files from `src/data/tilesets/metatiles.h`, as `%{tileset => path}`."
  def metatile_attributes(text) do
    for [name, path] <-
          Regex.scan(~r/gMetatileAttributes_(\w+)\[\] = INCBIN_U16\("([^"]+)"\)/, text,
            capture: :all_but_first
          ),
        into: %{},
        do: {"gTileset_" <> name, path}
  end

  @doc "Each script label in a map's `scripts.inc` to the first trainer constant it battles."
  def script_trainers(scripts) do
    for [label, body] <-
          Regex.scan(~r/^(\w+)::[^\n]*\n(.*?)(?=^\w+::|\z)/ms, scripts, capture: :all_but_first),
        [_, constant] <- [Regex.run(~r/^\s*trainerbattle_\w+ (TRAINER_\w+)/m, body)],
        into: %{},
        do: {label, constant}
  end

  @doc "A PokeAPI `evolution-chain` reply as `%{species => evolutions}`, Generation III species only."
  def evolutions(%{"chain" => chain}), do: chain |> walk() |> Map.new()

  defp walk(%{"species" => %{"name" => name}, "evolves_to" => next}) do
    next = Enum.filter(next, &gen3_species?/1)

    evolutions =
      for %{"species" => %{"name" => into}, "evolution_details" => details} <- next do
        detail = List.first(details) || %{}

        %{
          "into" => into,
          "min_level" => detail["min_level"],
          "trigger" => get_in(detail, ["trigger", "name"])
        }
      end

    [{name, evolutions} | Enum.flat_map(next, &walk/1)]
  end

  defp gen3_species?(%{"species" => %{"url" => url}}) do
    [id] = Regex.run(~r/(\d+)\/?$/, url, capture: :all_but_first)
    String.to_integer(id) <= @last_gen3_species
  end
end
