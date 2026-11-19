defmodule Mix.Tasks.Maya.FetchAccess do
  @shortdoc "Walks pokeemerald map layouts into priv/data/access.json (network, run by hand)"
  @moduledoc """
  Reads each listed location's `map.json`, `scripts.inc` and layout (`map.bin` plus its
  tilesets' metatile attributes) at the pokeemerald commit `mix maya.fetch_data` pins, walks
  it with `Maya.GameData.AccessMap` and `Maya.GameData.Access`, and writes `priv/data/access.json`: the balls, hidden items
  and trainers that need Cut, Surf or a later map. `mix maya.fetch_data` runs it last; run it
  alone to regenerate only this file. Spots no walk reaches are printed and get no row. Commit
  the output and review its diff: a row must never open a spot earlier than before.
  """
  use Mix.Task

  alias Maya.GameData.{Access, AccessMap, Parse}
  alias Mix.Tasks.Maya.FetchData

  @about "Balls, hidden items and trainers on a listed map that the player can reach only with an HM or from a later map, from mix maya.fetch_access: a walk over each map's layout (map.bin collision and elevation, one-way ledges, Cut trees as walls until Cut, rocks and boulders always walls) at the pinned pokeemerald commit. badges_required is the later of the map's and the badge that lets the HM be used outside battle (Cut 1, Surf 5); east Route 103 is reached from Route 110 (2 badges)."

  @impl Mix.Task
  def run(_args) do
    {:ok, _} = Application.ensure_all_started(:req)
    dir = Path.join(File.cwd!(), "priv/data")
    hand = &(dir |> Path.join(&1) |> File.read!() |> Jason.decode!())
    locations = hand.("locations.json")

    listed =
      Map.new(
        locations ++ Enum.map(hand.("interiors.json"), &Map.put(&1, "name", &1["city"])),
        &{&1["map"], {&1["badges_required"], &1["name"]}}
      )

    layouts =
      Map.new(
        get!("data/layouts/layouts.json") |> Jason.decode!() |> Map.fetch!("layouts"),
        &{&1["id"], &1}
      )

    fetched = FetchData.pmap(locations, &fetch_map!(&1, layouts))

    context = %{
      listed: listed,
      sizes: Map.new(fetched, fn {l, _, _, _, layout, _} -> {l["map"], layout} end),
      attributes: attributes!(fetched),
      behaviors: Parse.behaviors(get!("include/constants/metatile_behaviors.h")),
      balls: Parse.ball_scripts(get!("data/scripts/item_ball_scripts.inc")),
      trainers: Parse.trainer_constants(get!("src/data/trainers.h")),
      items:
        Parse.item_constants(
          get!("include/constants/items.h"),
          get!("include/constants/tms_hms.h")
        )
    }

    %{items: items, trainers: trainers, unreachable: unreachable} =
      fetched |> Enum.map(&AccessMap.decode(&1, context)) |> Access.rows()

    for spot <- unreachable, do: Mix.shell().info("unreachable even with every HM: #{spot}")
    File.write!(Path.join(dir, "access.json"), Access.encode(items, trainers, @about))
    Mix.shell().info("wrote #{length(items)} item and #{length(trainers)} trainer rows")
  end

  defp get!(path), do: FetchData.get_ok!(FetchData.pokeemerald_root() <> path)

  defp fetch_map!(location, layouts) do
    map_dir = Parse.map_dir(location["map"])
    {scripts, json} = FetchData.map!(location["map"], map_dir)
    layout = layouts[json["layout"]] || Mix.raise("unknown layout #{json["layout"]}")
    {location, map_dir, scripts, json, layout, get!(layout["blockdata_filepath"])}
  end

  # Each tileset's metatile_attributes.bin, by tileset name.
  defp attributes!(fetched) do
    paths = Parse.metatile_attributes(get!("src/data/tilesets/metatiles.h"))

    fetched
    |> Enum.flat_map(fn {_, _, _, _, l, _} -> [l["primary_tileset"], l["secondary_tileset"]] end)
    |> Enum.uniq()
    |> FetchData.pmap(&{&1, get!(paths[&1] || Mix.raise("no metatile attributes for #{&1}"))})
    |> Map.new()
  end
end
