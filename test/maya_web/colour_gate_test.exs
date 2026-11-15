defmodule MayaWeb.ColourGateTest do
  use ExUnit.Case, async: true

  # Scenarios from openspec/specs/design-system/spec.md, "No colour literals outside the token layer".
  # Colour literals live only between /* tokens:start */ and /* tokens:end */ in app.css.
  # The one exception: the root layout's theme-color metas (browsers need a literal).
  # design-apply emptied the legacy allow list, so there is no other exception.

  @literal ~r/#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3,4})\b|\b(?:rgba?|hsla?|oklch)\(/

  defp files do
    ["assets/css/app.css" | Path.wildcard("lib/maya_web/**/*.{ex,heex}")]
  end

  # Every literal outside the token layer, as "file:line".
  defp hits(path, text) do
    text
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.map_reduce(false, fn {line, n}, in_tokens ->
      in_tokens =
        cond do
          line =~ "/* tokens:start */" -> true
          line =~ "/* tokens:end */" -> false
          true -> in_tokens
        end

      count = if in_tokens or line =~ ~s(name="theme-color"), do: 0, else: count(line)
      {List.duplicate("#{path}:#{n}", count), in_tokens}
    end)
    |> elem(0)
    |> List.flatten()
  end

  defp count(line), do: @literal |> Regex.scan(line) |> length()

  defp scan(files_with_text) do
    Enum.flat_map(files_with_text, fn {path, text} -> hits(path, text) end)
  end

  defp tree, do: Enum.map(files(), &{&1, File.read!(&1)})

  test "no colour literal outside the token layer" do
    stray = scan(tree())

    assert stray == [], "colour literals outside the token layer: #{Enum.join(stray, ", ")}"
  end

  test "the legacy allow list is empty: no legacy-colours block is left" do
    for {path, text} <- tree(),
        do: refute(text =~ "legacy-colours", "legacy-colours block left in #{path}")
  end

  test "a literal outside the layer is caught with its file and line" do
    planted =
      {"assets/css/app.css",
       "/* tokens:start */\n--maya-x: #fff;\n/* tokens:end */\na { color: #123456; }"}

    assert scan([planted]) == ["assets/css/app.css:4"]
  end

  test "anchors and ids are not colour literals" do
    refute count(~s(<a href="#talk">)) > 0
    refute count(~s(<div id="conversation">)) > 0
    assert count("color: rgb(0 0 0 / 0.5); fill: #FFF") == 2
  end
end
