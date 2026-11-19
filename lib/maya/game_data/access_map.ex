defmodule Maya.GameData.AccessMap do
  @moduledoc """
  One listed map's pokeemerald sources, decoded into what `Maya.GameData.Access.rows/1` walks,
  pure: its grid (layout, Cut trees, rocks and boulders), its entries (connection edges and
  warps to listed maps) and its item and trainer spots. No IO: `mix maya.fetch_access` fetches.
  """
  alias Maya.GameData.{Access, Parse}

  @trees ["OBJ_EVENT_GFX_CUTTABLE_TREE"]
  @walls ["OBJ_EVENT_GFX_BREAKABLE_ROCK", "OBJ_EVENT_GFX_PUSHABLE_BOULDER"]

  @doc """
  A map for `Access.rows/1` from its `locations.json` row, `data/maps/` directory,
  `scripts.inc`, decoded `map.json`, `layouts.json` entry and `map.bin`. `context` holds
  `listed` (map to `{badges, name}`), `sizes` (map to layout), `attributes` (tileset to
  `metatile_attributes.bin`), `behaviors`, `balls`, `trainers` and `items` (from `Parse`).
  Raises on an item or trainer constant it does not know.
  """
  def decode({location, map_dir, scripts, json, layout, map_bin}, context) do
    objects = json["object_events"] || []
    grid = grid(layout, map_bin, objects, context)
    object = &Access.spawned(grid, spot(&1))
    script_trainers = Parse.script_trainers(scripts)
    # Trainers in scripts.inc order, as in trainer_places.json.
    order = scripts |> Parse.trainer_battles() |> Enum.with_index() |> Map.new()

    balls =
      for o <- objects,
          c = context.balls[o["script"]],
          do: {item!(context, c), "ball", object.(o)}

    hidden =
      for %{"type" => "hidden_item"} = b <- json["bg_events"] || [],
          do: {item!(context, b["item"]), "hidden", spot(b)}

    trainers =
      for(o <- objects, c = script_trainers[o["script"]], do: {order[c], c, object.(o)})
      |> Enum.sort_by(&elem(&1, 0))
      |> Enum.map(fn {_, c, at} -> {trainer!(context, c, location["map"]), at} end)

    %{
      map: location["map"],
      dir: map_dir,
      badges: location["badges_required"],
      grid: grid,
      entries: entries(json, layout, context),
      items: balls ++ hidden,
      trainers: trainers
    }
  end

  defp grid(layout, map_bin, objects, context) do
    tileset = &context.attributes[layout[&1]]
    at = &MapSet.new(for o <- objects, o["graphics_id"] in &1, do: {o["x"], o["y"]})

    %{
      width: layout["width"],
      height: layout["height"],
      tiles:
        Access.tiles(
          map_bin,
          tileset.("primary_tileset"),
          tileset.("secondary_tileset"),
          context.behaviors
        ),
      trees: at.(@trees),
      walls: at.(@walls)
    }
  end

  defp spot(event), do: {event["x"], event["y"], event["elevation"]}

  defp item!(context, constant),
    do: context.items[constant] || raise(ArgumentError, "unknown item #{constant}")

  defp trainer!(context, constant, map) do
    case context.trainers[constant] do
      {label, _name} -> label
      nil -> raise ArgumentError, "unknown trainer #{constant} on #{map}"
    end
  end

  # Each connection's edge tiles and each warp tile, open at the badges of the listed map on
  # the other side.
  defp entries(json, layout, context) do
    connections =
      for %{"map" => to} = c <- json["connections"] || [],
          {badges, name} <- [context.listed[to]],
          other <- [context.sizes[to]],
          other != nil,
          do: {badges, name, edge(c, layout, other)}

    warps =
      for %{"dest_map" => to, "x" => x, "y" => y} <- json["warp_events"] || [],
          {badges, name} <- [context.listed[to]],
          do: {badges, name, [{x, y}]}

    connections ++ warps
  end

  # A connection's offset places the other map along this map's edge.
  defp edge(%{"offset" => offset, "direction" => direction}, layout, other) do
    {w, h} = {layout["width"], layout["height"]}
    along = fn length, size -> max(offset, 0)..(min(offset + size, length) - 1)//1 end

    case direction do
      "up" -> for x <- along.(w, other["width"]), do: {x, 0}
      "down" -> for x <- along.(w, other["width"]), do: {x, h - 1}
      "left" -> for y <- along.(h, other["height"]), do: {0, y}
      "right" -> for y <- along.(h, other["height"]), do: {w - 1, y}
    end
  end
end
