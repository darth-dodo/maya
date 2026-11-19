defmodule Maya.GameData.Access do
  @moduledoc """
  The walk behind `priv/data/access.json`, pure, on decoded pokeemerald layouts: which item
  and trainer spots on a listed map need Cut, Surf or a later map, and at how many badges.

  It follows the game's movement rules (`src/event_object_movement.c`,
  `src/field_player_avatar.c`): a block's collision bits and elevation from `map.bin`,
  directional walls, one-way ledges, Surf on from elevation 3 and off onto elevation 3, and
  Cut trees as walls until Cut. Rock Smash rocks and Strength boulders always stay walls
  (fail closed). Other people are not walls. A map is entered on the edge of each connection
  and at each warp to a listed map, open at that map's badges. A spot is reached when the
  player can face it from a tile next to it.

  shortcut: currents and waterfalls are walked as plain water (none is on a listed map up to
  Mauville City), and bikes and unlisted maps (houses, gatehouses, caves) are not walked,
  which can only keep a spot later or unreached; model them when a listed map has one.
  """
  import Bitwise

  @primary_metatiles 512
  # The badge that lets the HM be used outside battle.
  @cut 1
  @surf 5
  @last_badge 8
  @default_elevation 3
  @multi_level 15
  @fishable ~w(MB_POND_WATER MB_OCEAN_WATER MB_INTERIOR_DEEP_WATER MB_DEEP_WATER
               MB_SOOTOPOLIS_DEEP_WATER MB_EASTWARD_CURRENT MB_WESTWARD_CURRENT
               MB_NORTHWARD_CURRENT MB_SOUTHWARD_CURRENT)
  @dirs [{"NORTH", {0, -1}}, {"SOUTH", {0, 1}}, {"WEST", {-1, 0}}, {"EAST", {1, 0}}]
  @opposite %{"NORTH" => "SOUTH", "SOUTH" => "NORTH", "WEST" => "EAST", "EAST" => "WEST"}

  @doc """
  A layout's `map.bin` as a tuple of `{collision, elevation, behavior}`, row by row. A block
  is a little-endian u16 (metatile id, collision, elevation); metatile ids from 512 are the
  secondary tileset's. `behaviors` is `Parse.behaviors/1`.
  """
  def tiles(map_bin, primary, secondary, behaviors) do
    for <<block::little-16 <- map_bin>> do
      id = block &&& 0x3FF

      {attributes, index} =
        if id < @primary_metatiles, do: {primary, id}, else: {secondary, id - @primary_metatiles}

      <<attribute::little-16>> = binary_part(attributes, index * 2, 2)
      {block >>> 10 &&& 3, block >>> 12, elem(behaviors, attribute &&& 0xFF)}
    end
    |> List.to_tuple()
  end

  @doc """
  Where the player can stand, as `{x, y, elevation}`, from the `seeds` tiles `{x, y}`, with or
  without Cut and Surf. `grid` has `width`, `height`, `tiles`, `trees` (Cut) and `walls`.
  """
  def reach(grid, seeds, cut?, surf?) do
    blocked = if cut?, do: grid.walls, else: MapSet.union(grid.walls, grid.trees)
    starts = for p <- Enum.uniq(seeds), s = seed(grid, blocked, p, surf?), do: s

    grid
    |> flood(blocked, surf?, starts, MapSet.new(starts))
    |> MapSet.new(fn {x, y, elevation, _} -> {x, y, elevation} end)
  end

  @doc """
  Whether the player can face any of `spots` (`{x, y, elevation}`) from a tile next to it in
  `reach`. As in the game, the two elevations match or one is 0, so a trainer on a bridge is
  not reached from the water below.
  """
  def reached?(reach, spots) do
    Enum.any?(spots, fn {x, y, elevation} ->
      Enum.any?(@dirs, fn {_, {dx, dy}} ->
        Enum.any?(facing(elevation), &MapSet.member?(reach, {x + dx, y + dy, &1}))
      end)
    end)
  end

  @doc """
  An object event's elevation once spawned: its tile's, unless that is multi level (15), then
  the `map.json` one (`ObjectEventUpdateElevation`). Hidden items keep theirs.
  """
  def spawned(grid, {x, y, elevation}) do
    case tile(grid, {x, y}) do
      {_, @multi_level, _} -> {x, y, elevation}
      {_, to, _} -> {x, y, to}
    end
  end

  defp facing(0), do: 0..@multi_level
  defp facing(elevation), do: [0, elevation]

  @doc """
  `access.json` rows for the walked maps, plus the spots no walk reaches. Each map has `map`,
  `dir`, `badges`, `grid`, `entries` (`{badges, name, tiles}`), `items` (`{item, how, at}`)
  and `trainers` (`{label, at}`), each `at` being `{x, y, elevation}`. A row is written when
  a spot needs more than its map's badges: the first badge count, then the fewest HMs, that
  reaches it. Copies of one item on a map share a row, so the latest copy decides (fail
  closed); a double battle is reached from either trainer. An unreached spot gets no row, so
  it keeps its map's badges: the task prints it for the reviewer.
  """
  def rows(maps) do
    walked = Enum.map(maps, &{&1, levels(&1)})

    items =
      for {map, levels} <- walked,
          {{item, how}, spots} <- group(map.items, fn {i, h, at} -> {{i, h}, at} end),
          reached = for(at <- spots, level = first(levels, [at]), do: {level, at}),
          reached != [],
          {{badges, _, _} = level, {x, y, _} = at} =
            Enum.max_by(reached, fn {{b, _, _}, _} -> b end),
          badges > map.badges,
          do: [
            {"item", item},
            {"map", map.map},
            {"how", how},
            {"needs", needs(map, level, [at])},
            {"badges_required", badges},
            {"source", "data/maps/#{map.dir}/map.json (#{x},#{y})"}
          ]

    trainers =
      for {map, levels} <- walked,
          {label, spots} <- group(map.trainers, & &1),
          {badges, _, _} = level <- [first(levels, spots)],
          badges > map.badges,
          do: [
            {"label", label},
            {"map", map.map},
            {"needs", needs(map, level, spots)},
            {"badges_required", badges},
            {"source", "data/maps/#{map.dir}/map.json"}
          ]

    unreachable =
      for {map, levels} <- walked,
          {name, at} <-
            Enum.map(map.items, fn {i, h, at} -> {"#{i} (#{h})", at} end) ++ map.trainers,
          first(levels, [at]) == nil,
          do: "#{map.map} #{name} at #{inspect(at)}"

    %{items: items, trainers: trainers, unreachable: unreachable}
  end

  @doc "`access.json` text: one row per line, keys in row order, as the hand-written file had."
  def encode(items, trainers, about) do
    rows =
      &Enum.map_join(&1, ",\n", fn row -> row |> Jason.OrderedObject.new() |> Jason.encode!() end)

    ~s({\n"about": #{Jason.encode!(about)},\n"items": [\n#{rows.(items)}\n],\n"trainers": [\n#{rows.(trainers)}\n]\n}\n)
  end

  # Every {badges, cut?, surf?} from the map's badges up, fewest HMs first, with its reach.
  defp levels(map) do
    for badges <- map.badges..@last_badge//1,
        {cut?, surf?} <- [{false, false}, {true, false}, {false, true}, {true, true}],
        badges >= @cut or not cut?,
        badges >= @surf or not surf?,
        do: {{badges, cut?, surf?}, reach(map.grid, seeds(map, badges), cut?, surf?)}
  end

  defp first(levels, spots),
    do: Enum.find_value(levels, fn {level, reach} -> reached?(reach, spots) && level end)

  defp seeds(map, badges),
    do: for({b, _, tiles} <- map.entries, b <= badges, tile <- tiles, do: tile)

  defp needs(map, {badges, cut?, surf?}, spots) do
    hm =
      case {cut?, surf?} do
        {false, false} -> "foot"
        {true, false} -> "cut"
        {false, true} -> "surf"
        {true, true} -> "cut and surf"
      end

    if reached?(reach(map.grid, seeds(map, map.badges), cut?, surf?), spots) do
      hm
    else
      from =
        for {b, name, _} <- map.entries, b > map.badges and b <= badges, uniq: true, do: name

      hm <> ", from " <> Enum.join(from, " or ")
    end
  end

  # Groups in first-seen order.
  defp group(rows, split) do
    pairs = Enum.map(rows, split)
    groups = Enum.group_by(pairs, &elem(&1, 0), &elem(&1, 1))
    pairs |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> Enum.map(&{&1, groups[&1]})
  end

  defp seed(grid, blocked, {x, y} = p, surf?) do
    case tile(grid, p) do
      nil -> nil
      {collision, _, _} when collision != 0 -> nil
      {_, elevation, behavior} -> seed_state(blocked, p, {x, y, elevation}, behavior, surf?)
    end
  end

  defp seed_state(blocked, p, {x, y, elevation}, behavior, surf?) do
    cond do
      MapSet.member?(blocked, p) -> nil
      behavior in @fishable -> if surf?, do: {x, y, elevation, true}
      true -> {x, y, elevation, false}
    end
  end

  defp flood(_grid, _blocked, _surf?, [], seen), do: seen

  defp flood(grid, blocked, surf?, [state | rest], seen) do
    next =
      for dir <- @dirs,
          n = step(grid, blocked, surf?, state, dir),
          not MapSet.member?(seen, n),
          uniq: true,
          do: n

    flood(grid, blocked, surf?, next ++ rest, Enum.into(next, seen))
  end

  defp step(grid, blocked, surf?, {x, y, elevation, surfing} = state, {dir, {dx, dy}}) do
    to = {x + dx, y + dy}

    case tile(grid, to) do
      nil ->
        nil

      {_, _, "MB_JUMP_" <> ^dir} when not surfing ->
        land(grid, {x + 2 * dx, y + 2 * dy}, elevation)

      target ->
        if MapSet.member?(blocked, to) or wall?(grid, {x, y}, target, dir),
          do: nil,
          else: move(state, to, target, surf?)
    end
  end

  # shortcut: a ledge jump lands two tiles on without checking that tile (the game does not
  # either; maps draw floor there), add a check if a listed map ever lands on a wall.
  defp land(grid, {x, y} = p, elevation) do
    case tile(grid, p) do
      nil -> nil
      {_, to, _} -> {x, y, next_elevation(elevation, to), false}
    end
  end

  defp wall?(grid, from, {collision, _, behavior}, dir) do
    {_, _, leaving} = tile(grid, from)
    collision != 0 or blocks?(leaving, dir) or blocks?(behavior, @opposite[dir])
  end

  defp blocks?("MB_IMPASSABLE_" <> sides, dir), do: String.contains?(sides, dir)
  defp blocks?(_behavior, _dir), do: false

  defp move({_, _, elevation, surfing}, {x, y}, {_, to, behavior}, surf?) do
    cond do
      not mismatch?(elevation, to) ->
        {x, y, next_elevation(elevation, to), surfing}

      surfing and to == @default_elevation ->
        {x, y, to, false}

      not surfing and surf? and elevation == @default_elevation and behavior in @fishable ->
        {x, y, to, true}

      true ->
        nil
    end
  end

  # Elevation 0 is a transition and 15 is multi level: both match any.
  defp mismatch?(0, _to), do: false
  defp mismatch?(_elevation, to) when to in [0, @multi_level], do: false
  defp mismatch?(elevation, to), do: elevation != to

  defp next_elevation(elevation, @multi_level), do: elevation
  defp next_elevation(_elevation, to), do: to

  defp tile(%{width: w, height: h, tiles: tiles}, {x, y})
       when x >= 0 and y >= 0 and x < w and y < h,
       do: elem(tiles, y * w + x)

  defp tile(_grid, _p), do: nil
end
