defmodule MayaWeb.ColourGateTest do
  use ExUnit.Case, async: true

  # Scenarios from openspec/specs/design-system/spec.md, "No colour literals outside the token layer".
  # Colour literals live only between /* tokens:start */ and /* tokens:end */ in app.css.
  # Exceptions: the root layout's theme-color metas (browsers need a literal), and today's
  # per-page blocks, each wrapped in `legacy-colours:start <name>` / `legacy-colours:end` markers.
  # design-apply moves those onto tokens and empties this allow list; it may only shrink.
  @legacy %{"talk-screen" => 52, "home" => 17, "footer-art" => 8}

  @literal ~r/#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3,4})\b|\b(?:rgba?|hsla?|oklch)\(/

  defp files do
    ["assets/css/app.css" | Path.wildcard("lib/maya_web/**/*.{ex,heex}")]
  end

  # Every literal outside the token layer, as {region or nil, "file:line"}.
  defp hits(path, text) do
    text
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.map_reduce(%{tokens: false, region: nil}, fn {line, n}, state ->
      state =
        cond do
          line =~ "/* tokens:start */" -> %{state | tokens: true}
          line =~ "/* tokens:end */" -> %{state | tokens: false}
          line =~ "legacy-colours:start" -> %{state | region: legacy_name(line)}
          line =~ "legacy-colours:end" -> %{state | region: nil}
          true -> state
        end

      count = if state.tokens or line =~ ~s(name="theme-color"), do: 0, else: count(line)
      {List.duplicate({state.region, "#{path}:#{n}"}, count), state}
    end)
    |> elem(0)
    |> List.flatten()
  end

  defp legacy_name(line),
    do: Regex.run(~r/legacy-colours:start ([a-z-]+)/, line, capture: :all_but_first) |> hd()

  defp count(line), do: @literal |> Regex.scan(line) |> length()

  defp scan(files_with_text) do
    Enum.flat_map(files_with_text, fn {path, text} -> hits(path, text) end)
  end

  defp tree, do: Enum.map(files(), &{&1, File.read!(&1)})

  test "no colour literal outside the token layer, except the counted legacy blocks" do
    hits = scan(tree())
    stray = for {nil, where} <- hits, do: where

    assert stray == [], "colour literals outside the token layer: #{Enum.join(stray, ", ")}"

    found = hits |> Enum.frequencies_by(&elem(&1, 0))
    assert found == @legacy, "legacy allow list drifted: found #{inspect(found)}"

    IO.puts("colour gate: #{Enum.sum(Map.values(@legacy))} legacy literals left for design-apply")
  end

  test "a literal outside the layer is caught with its file and line" do
    planted =
      {"assets/css/app.css",
       "/* tokens:start */\n--maya-x: #fff;\n/* tokens:end */\na { color: #123456; }"}

    assert scan([planted]) == [{nil, "assets/css/app.css:4"}]
  end

  test "anchors and ids are not colour literals" do
    refute count(~s(<a href="#talk">)) > 0
    refute count(~s(<div id="conversation">)) > 0
    assert count("color: rgb(0 0 0 / 0.5); fill: #FFF") == 2
  end
end
