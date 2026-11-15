defmodule MayaWeb.DesignApplyTest do
  use ExUnit.Case, async: true

  # Static checks of the page rules in app.css for the design-apply scenarios (talk-screen,
  # landing-page, factory-page). The computed style checks in a browser are in the PR.

  defp pages do
    [_, rules] = String.split(File.read!("assets/css/app.css"), "/* tokens:end */", parts: 2)
    rules
  end

  # The declarations of the first rule whose selector is exactly `selector`.
  defp rule(selector) do
    ~r/([^{}]+)\{([^{}]*)\}/
    |> Regex.scan(pages(), capture: :all_but_first)
    |> Enum.find_value(fn [sel, body] ->
      if sel |> String.replace(~r{/\*.*?\*/}s, "") |> String.trim() == selector, do: decls(body)
    end) || flunk("no #{selector} rule in app.css")
  end

  defp decls(body) do
    for decl <- String.split(body, ";"),
        [prop, value] <- [String.split(decl, ":", parts: 2)],
        into: %{},
        do: {String.trim(prop), String.trim(value)}
  end

  test "Talk screen follows the theme: bg token, no forced light scene" do
    assert rule(".talk-screen")["background-color"] == "var(--maya-bg)"
    refute pages() =~ "color-scheme: light"
  end

  test "trainer card: opaque surface, gold hairline border (transparent by day), soft shadow" do
    card = rule(".trainer-card")
    assert card["background"] == "var(--maya-surface)"
    assert card["border"] =~ "var(--maya-hairline)"
    assert card["box-shadow"] == "var(--maya-shadow-1)"
  end

  test "the ball glows only through the glow token (none by day)" do
    assert rule(".pokeball")["box-shadow"] == "var(--maya-glow)"
  end

  test "Talk button and home call to action use the action colour" do
    assert rule(".talk-button")["background"] == "var(--maya-action)"
    assert rule(".home-cta")["background"] == "var(--maya-action)"
  end

  test "the Talk button keeps one border width in every state, so it never resizes under the finger" do
    refute pages() =~
             ~r/\.talk-button\[data-state[^{]*\{[^}]*(border|padding|min-height|font-size)/
  end

  test "gym line and home tagline in the heading font" do
    assert rule(".card-gym")["font-family"] == "var(--maya-font-head)"
    assert rule(".home-tagline")["font-family"] == "var(--maya-font-head)"
  end

  test "sticky card stays compact with a full Team: chips wrap across the card's full width (#117)" do
    assert rule(".card-team")["grid-column"] == "1 / -1"
  end

  test "every transition uses the shared duration and easing" do
    for [value] <- Regex.scan(~r/transition:([^;]+);/, pages(), capture: :all_but_first),
        part <- String.split(value, ",") do
      assert part =~ "var(--maya-duration)" and part =~ "var(--maya-ease)", part
    end
  end

  test "fonts only from the font tokens" do
    for [value] <- Regex.scan(~r/font-family:([^;]+);/, pages(), capture: :all_but_first),
        do: assert(value =~ ~r/^\s*var\(--maya-font-(head|body)\)\s*$/, value)
  end
end
