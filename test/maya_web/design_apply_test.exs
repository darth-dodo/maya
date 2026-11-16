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

  # tide-cohesion: Talk screen without containers
  test "no scene panel and no card box: no border, radius, shadow or panel art" do
    for prop <- ~w(border border-bottom border-radius background-image),
        do: refute(Map.has_key?(rule(".talk-screen"), prop), ".talk-screen #{prop}")

    for prop <- ~w(border border-bottom border-radius box-shadow),
        do: refute(Map.has_key?(rule(".trainer-card"), prop), ".trainer-card #{prop}")
  end

  # tide-cohesion: one fade recipe for the hero and the Talk band, tide by day and night at night
  test "one art band for the hero and the trainer card, no scrim, night art in both night scopes" do
    band = rule(".home-tide .home-hero, .trainer-card")

    assert band["background"] =~
             "linear-gradient(transparent 0 var(--band-clear), var(--maya-bg) var(--band-solid))"

    assert band["background"] =~ "var(--band-art)"
    assert band["--band-art"] == ~s|url("/images/backdrops/tide.jpg")|
    refute pages() =~ "color-mix(in srgb, var(--maya-bg) 85%"

    for scope <- [
          ~S|:root[data-theme="dark"] :is(.home-tide .home-hero, .trainer-card)|,
          ~S|:root:not([data-theme="light"]) :is(.home-tide .home-hero, .trainer-card)|
        ],
        do: assert(rule(scope)["--band-art"] == ~s|url("/images/backdrops/night.jpg")|)
  end

  test "the Talk band is shorter than the hero: its fade is solid by 3.5rem, the hero's by 9.5rem" do
    assert rule(".trainer-card")["--band-solid"] == "3.5rem"
    assert rule(".home-tide .home-hero")["--band-clear"] == "6rem"
    assert rule(".home-tide .home-hero")["--band-solid"] == "9.5rem"
  end

  test "eyebrow separator has a plain content line first, for Safari before 17.4" do
    assert pages() =~
             ~r/\.card-eyebrow \.badge-count::before\s*\{\s*content: "·";\s*content: "·" \/ "";/
  end

  test "header keeps one height in every moment: no per-state layout rule on the card" do
    refute pages() =~
             ~r/\.talk-screen[^{]*data-state[^{]*(\.trainer-card|\.pokeball|\.card-team|\.card-badges)\s*[,{]/
  end

  test "Team chips wrap instead of scrolling" do
    assert rule(".card-team")["flex-wrap"] == "wrap"
  end

  # tide-talk: Short chat, unboxed
  test "turns are unboxed with a hairline between them" do
    for sel <- [".turn .you", ".turn .maya"] do
      decls = rule(sel)

      for prop <- ~w(background border box-shadow),
          do: refute(Map.has_key?(decls, prop), "#{sel} #{prop}")
    end

    assert rule(".turn + .turn")["border-top"] == "1px solid var(--maya-line)"
  end

  test "every Question is small and muted, like the homepage real turn" do
    assert rule(".turn .you")["font-size"] == "var(--maya-text-sm)"
    assert rule(".turn .you")["color"] == "var(--maya-muted)"
    assert rule(".home-tide .real-turn-question")["font-size"] == "var(--maya-text-sm)"
  end

  test "older turns are muted at body size; the latest Answer is the largest text" do
    turn = rule(".turn")
    assert turn["color"] == "var(--maya-muted)"
    assert turn["font-size"] == "var(--maya-text-base)"
    assert rule(".turn.now .maya")["font-size"] == "var(--maya-text-xl)"
  end

  # tide-talk: Talk button in the thumb zone
  test "Talk button is a 72px pill" do
    button = rule(".talk-button")
    assert button["min-height"] == "4.5rem"
    assert button["border-radius"] == "var(--maya-radius-pill)"
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

  # tide-cohesion: the new headline
  test "home headline in Fraunces italic 600, about 52px on a phone" do
    heading = rule(".home-tide .home-heading")
    assert heading["font-style"] == "italic"
    assert heading["font-weight"] == "600"
    assert heading["font-size"] == "clamp(2.75rem, 14vw, 3.5rem)"
  end

  test "review fixes: no dead demo or catchphrase CSS, the promise band scoped to .home-tide" do
    refute pages() =~ "demo-"
    refute pages() =~ ".home-catchphrase"
    refute pages() =~ ~r/^\.promise-band/m
    assert rule(".home-tide .promise-band")["background"] == "var(--maya-sea)"
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
