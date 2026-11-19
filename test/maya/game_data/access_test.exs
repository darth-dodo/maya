defmodule Maya.GameData.AccessTest do
  use ExUnit.Case, async: true

  import Bitwise

  alias Maya.GameData.Access

  # One character per block: floor and wall at elevation 3, water at 1, a ledge to jump south.
  defp grid(rows, trees \\ []) do
    lines = rows |> String.trim() |> String.split("\n")

    %{
      width: byte_size(hd(lines)),
      height: length(lines),
      tiles: List.to_tuple(for line <- lines, <<c <- line>>, do: tile(c)),
      trees: MapSet.new(trees),
      walls: MapSet.new()
    }
  end

  defp tile(?.), do: {0, 3, "MB_NORMAL"}
  defp tile(?#), do: {1, 3, "MB_NORMAL"}
  defp tile(?~), do: {0, 1, "MB_OCEAN_WATER"}
  defp tile(?v), do: {1, 3, "MB_JUMP_SOUTH"}
  defp tile(?>), do: {0, 3, "MB_IMPASSABLE_EAST"}

  defp rows(grid, entries, spots) do
    map = %{
      map: "MAP_ROUTE103",
      dir: "Route103",
      badges: 0,
      grid: grid,
      entries: entries,
      items: Keyword.get(spots, :items, []),
      trainers: Keyword.get(spots, :trainers, [])
    }

    Access.rows([map])
  end

  defp row(rows, name),
    do: rows |> Enum.map(&Map.new/1) |> Enum.find(&(&1["item"] == name or &1["label"] == name))

  defp tiles(reach), do: MapSet.new(reach, fn {x, y, _} -> {x, y} end)

  test "a block is its collision, elevation and behavior; ids from 512 are the secondary tileset's" do
    primary = <<0::little-16, 1::little-16>>
    secondary = <<0::little-16, 2::little-16>>
    blocks = <<1 ||| 3 <<< 12::little-16, 513 ||| 1 <<< 10 ||| 1 <<< 12::little-16>>
    behaviors = {"MB_NORMAL", "MB_TALL_GRASS", "MB_OCEAN_WATER"}

    assert Access.tiles(blocks, primary, secondary, behaviors) ==
             {{0, 3, "MB_TALL_GRASS"}, {1, 1, "MB_OCEAN_WATER"}}
  end

  test "a ball behind a Cut tree waits for the Cut badge (X Accuracy on Route 104)" do
    result =
      rows(grid(".....", [{2, 0}]), [{0, "Petalburg City", [{0, 0}]}],
        items: [{"x accuracy", "ball", {4, 0, 3}}]
      )

    assert %{
             "needs" => "cut",
             "badges_required" => 1,
             "source" => "data/maps/Route103/map.json (4,0)"
           } =
             row(result.items, "x accuracy")
  end

  test "a ball across the water waits for the Surf badge (Max Revive in Petalburg City)" do
    result =
      rows(grid("..~~.."), [{0, "Route 102", [{0, 0}]}],
        items: [{"max revive", "ball", {5, 0, 3}}]
      )

    assert %{"needs" => "surf", "badges_required" => 5} = row(result.items, "max revive")
  end

  test "a spot on foot gets no row" do
    result =
      rows(grid("...."), [{0, "Oldale Town", [{0, 0}]}], items: [{"potion", "ball", {3, 0, 3}}])

    assert result.items == []
  end

  test "east Route 103 waits for Route 110 at 2 badges, behind Cut or on foot" do
    result =
      rows(
        grid("..#......", [{6, 0}]),
        [{0, "Oldale Town", [{0, 0}]}, {2, "Route 110", [{3, 0}]}],
        items: [{"guard spec", "ball", {8, 0, 3}}],
        trainers: [{"Daisy", {4, 0, 3}}]
      )

    assert %{"needs" => "cut, from Route 110", "badges_required" => 2} =
             row(result.items, "guard spec")

    assert %{"needs" => "foot, from Route 110", "badges_required" => 2} =
             row(result.trainers, "Daisy")
  end

  test "a ball behind a tree across the water needs both HMs" do
    result =
      rows(grid("..~~...", [{5, 0}]), [{0, "Route 102", [{0, 0}]}],
        items: [{"rare candy", "ball", {6, 0, 3}}]
      )

    assert %{"needs" => "cut and surf", "badges_required" => 5} = row(result.items, "rare candy")
  end

  test "a block walled on its east side is left only west" do
    reach = tiles(Access.reach(grid(".>."), [{0, 0}], false, false))
    assert MapSet.member?(reach, {1, 0})
    refute MapSet.member?(reach, {2, 0})
  end

  test "access.json keeps one row per line with keys in row order" do
    assert Access.encode(
             [[{"item", "pp up"}, {"map", "MAP_ROUTE104"}]],
             [[{"label", "Daisy"}]],
             "a"
           ) ==
             ~s({\n"about": "a",\n"items": [\n{"item":"pp up","map":"MAP_ROUTE104"}\n],\n) <>
               ~s("trainers": [\n{"label":"Daisy"}\n]\n}\n)
  end

  test "a ledge is one way" do
    g = grid("...\nvvv\n...")
    assert MapSet.member?(tiles(Access.reach(g, [{0, 0}], false, false)), {0, 2})
    refute MapSet.member?(tiles(Access.reach(g, [{0, 2}], false, false)), {0, 0})
  end

  test "a spot is faced only at a matching elevation, or 0" do
    reach = MapSet.new([{0, 0, 1}])
    refute Access.reached?(reach, [{1, 0, 4}])
    assert Access.reached?(reach, [{1, 0, 1}])
    assert Access.reached?(reach, [{1, 0, 0}])
  end

  test "a spot no walk reaches gets no row and is listed" do
    result = rows(grid("..#."), [{0, "Oldale Town", [{0, 0}]}], trainers: [{"Jacob", {3, 0, 3}}])
    assert result.trainers == []
    assert result.unreachable == ["MAP_ROUTE103 Jacob at {3, 0, 3}"]
  end

  test "the committed access.json keeps the known spots" do
    access = "priv/data/access.json" |> File.read!() |> Jason.decode!()
    find = &Enum.find(access["items"], fn i -> i["item"] == &1 and i["map"] == &2 end)

    assert %{"needs" => "cut", "badges_required" => 1} = find.("x accuracy", "MAP_ROUTE104")
    assert %{"needs" => "cut", "badges_required" => 1} = find.("x attack", "MAP_PETALBURG_WOODS")

    assert %{"needs" => "surf", "badges_required" => 5} =
             find.("max revive", "MAP_PETALBURG_CITY")

    assert %{"needs" => "cut, from Route 110", "badges_required" => 2} =
             find.("guard spec", "MAP_ROUTE103")
  end
end
