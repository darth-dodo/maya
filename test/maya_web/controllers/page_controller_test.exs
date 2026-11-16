defmodule MayaWeb.PageControllerTest do
  # No database: the home page reads none, so this runs without the SQL sandbox.
  use ExUnit.Case, async: true

  import Plug.Conn
  import Phoenix.ConnTest
  use MayaWeb, :verified_routes

  @endpoint MayaWeb.Endpoint

  # Scenarios from openspec/specs/landing-page/spec.md (the public home page at /).

  @later_leaders ~w(Brawly Wattson Flannery Norman Winona Tate Liza Juan)
  @evolved_starters ~w(Grovyle Sceptile Combusken Blaziken Marshtomp Swampert)

  defp home, do: build_conn() |> get(~p"/") |> html_response(200)

  defp doc(html), do: LazyHTML.from_document(html)
  defp query(html, selector), do: html |> doc() |> LazyHTML.query(selector)
  defp text_of(html, selector), do: html |> query(selector) |> LazyHTML.text() |> squish()
  defp texts(html, selector), do: html |> query(selector) |> Enum.map(&squish(LazyHTML.text(&1)))
  defp count(html, selector), do: html |> query(selector) |> Enum.count()
  defp attrs(html, selector, name), do: html |> query(selector) |> LazyHTML.attribute(name)
  defp squish(text), do: text |> String.split() |> Enum.join(" ")

  # The homepage block of app.css: from its opening comment to the factory page block.
  defp home_css do
    css = File.read!("assets/css/app.css")
    [_, rest] = String.split(css, "/* Public home page at /", parts: 2)
    [block, _] = String.split(rest, "/* Public factory page", parts: 2)
    block
  end

  test "visitor without a login opens the home page" do
    conn = get(build_conn(), ~p"/")
    html = html_response(conn, 200)

    assert text_of(html, "header a[href='/']") == "Maya"
    assert text_of(html, "header a#header-talk-link[href='/talk']") == "Talk"
    assert count(html, "h1") == 1
    assert text_of(html, "h1#home-heading") == "Ask out loud. No spoilers."
    assert text_of(html, "#home-tagline") == "Maps, Answers, Yaps, Advice."

    assert text_of(html, "#home-catchphrase") ==
             "So I hear you like Mudkip. Good. Correct choice."

    for id <- ~w(#talk-screen #talk-heading #talk-button), do: assert(count(html, id) == 0, id)
  end

  test "the factory page header links to Talk too" do
    factory = build_conn() |> get(~p"/factory") |> html_response(200)
    assert text_of(factory, "header a#header-talk-link[href='/talk']") == "Talk"
  end

  test "way in for friends links to the Talk screen" do
    html = home()
    assert attrs(html, "#talk-link", "href") == ["/talk"]
    assert text_of(html, "#talk-link") == "Talk to Maya"
  end

  test "browser tab title is Maya and generator content is gone" do
    html = home()

    assert text_of(html, "head title") == "Maya"
    body = text_of(html, "body")
    refute body =~ "Peace of mind from prototype to production"
    refute body =~ "Phoenix Framework"

    for href <- attrs(html, "a[href]", "href"),
        bad <- ~w(github.com/phoenixframework phoenixframework.org hexdocs.pm),
        do: refute(href =~ bad, href)
  end

  test "hero parts: eyebrow, heading, call to action and mic note, no image or ball" do
    html = home()

    assert text_of(html, "#home-hero #home-eyebrow") == "A Pokémon Emerald companion"

    for id <- ~w(#home-heading #talk-link #mic-note),
        do: assert(count(html, "#home-hero #{id}") == 1, id)

    assert text_of(html, "#mic-note") ==
             "The mic is on while you hold, and off a few seconds after."

    assert count(html, "#home-hero img, #home-hero #pokeball") == 0
  end

  test "static page: no LiveView and no Conversation" do
    conn = get(build_conn(), ~p"/")
    html = html_response(conn, 200)

    assert count(html, "[data-phx-main]") == 0
    guest = get_session(conn, :guest_id)
    assert Registry.lookup(Maya.ConversationRegistry, {:conversation, guest}) == []
  end

  test "only own assets, no frames, no video and no img" do
    html = home()

    refs =
      attrs(html, "[src]", "src") ++
        attrs(html, "[poster]", "poster") ++ attrs(html, "link[rel=stylesheet]", "href")

    assert refs != []

    for ref <- refs,
        do: assert(String.starts_with?(ref, "/") and not String.starts_with?(ref, "//"), ref)

    assert count(html, "iframe, embed, video, img") == 0
  end

  test "backdrops from own origin: every url() in the homepage block" do
    urls = Regex.scan(~r/url\(\s*["']?([^"')]+)/, home_css(), capture: :all_but_first)
    assert urls != []

    for [url] <- urls,
        do: assert(String.starts_with?(url, ["/images/backdrops/", "/fonts/"]), url)
  end

  test "a real turn: Question, Answer and the recorded median" do
    html = home()

    assert text_of(html, "#real-turn #real-turn-question") == "Where do I go next?"

    assert text_of(html, "#real-turn #real-turn-answer") ==
             "Head north to Rustboro City for Roxanne. Mudkip's Water moves make it a short fight."

    assert count(html, "#real-turn-answer *") == 0
    assert text_of(html, "#real-turn-latency") == "Median Answer time 4.95 s over 145 turns"
  end

  test "the real turn caption follows the recorded value" do
    assert MayaWeb.PageHTML.real_turn_caption(%{median_s: 4.2, turns: 200}) ==
             "Median Answer time 4.20 s over 200 turns"
  end

  test "Meet Maya: heading, CSS ball, catchphrase bubble and tagline" do
    html = home()

    assert text_of(html, "#meet-maya h2") == "Meet Maya. She has opinions."

    for id <- ~w(#pokeball.pokeball-emerald #home-catchphrase #home-tagline),
        do: assert(count(html, "#meet-maya #{id}") == 1, id)

    assert count(html, "#pokeball img") == 0
  end

  test "five Dials, read only" do
    html = home()

    assert texts(html, "#meet-maya #dials .dial") ==
             ["Humor 75", "Honesty 90", "Sass 40", "Mudkip hype 100", "Spoilers 0, locked"]

    assert count(html, "#dials :is(input, button, select, form, [role=slider])") == 0
    meet = text_of(html, "#meet-maya") |> String.downcase()
    refute meet =~ "change"
    refute meet =~ "ask her"
  end

  test "Dial values match her prompt and the seed humor" do
    prompt = "lib/maya/agent/prompt.ex" |> File.read!() |> String.downcase()
    seed = "priv/progress.json" |> File.read!() |> Jason.decode!()

    for {name, value, locked?} <- MayaWeb.PageHTML.dials() do
      case name do
        "Humor" ->
          assert value == seed["humor"]
          assert prompt =~ "humor \#{progress.humor}"

        name ->
          label = String.downcase(name) <> " #{value}" <> if(locked?, do: " (locked)", else: "")
          assert prompt =~ label, label
      end
    end
  end

  test "things she says: three real lines in order" do
    html = home()
    prompt = File.read!("lib/maya/agent/prompt.ex")

    sayings = [
      "Mudkip would approve.",
      "Further ahead, no spoilers.",
      "Mudkip is a pure Water type, and Maya is not biased at all."
    ]

    assert texts(html, "#meet-maya #sayings .saying") == sayings
    for line <- Enum.take(sayings, 2), do: assert(prompt =~ line, line)
  end

  test "voice loop: four ruled steps in order and no invented latency" do
    html = home()

    assert text_of(html, "#voice-loop h2") == "How a turn works"

    assert texts(html, "#voice-loop ol .loop-step") ==
             ["Hold", "Transcribe", "Agent with tools", "Speak"]

    assert count(html, "#latency-pending") == 1
    refute text_of(html, "#voice-loop") =~ ~r/\d+(\.\d+)?\s?(ms|s)\b/
  end

  test "spoiler promise band: heading and the CI gate item only" do
    html = home()

    assert text_of(html, "#spoiler-promise h2") == "Further ahead, no spoilers."
    assert text_of(html, "#spoiler-promise #promise-ci-gate") != ""
    assert count(html, "#promise-facts, #promise-horizon") == 0
  end

  test "gate wording stays honest while CI has no spoiler job" do
    ci = File.read!(Path.expand("../../../.github/workflows/ci.yml", __DIR__))
    spoiler_job? = Regex.match?(~r/^  [\w-]*spoiler[\w-]*:\s*$/m, ci)

    if spoiler_job? do
      refute text_of(home(), "#promise-ci-gate") =~ "planned"
    else
      assert text_of(home(), "#promise-ci-gate") =~ "planned"
    end
  end

  test "home page stays spoiler-free" do
    page = text_of(home(), "html")

    for name <- @later_leaders ++ @evolved_starters,
        do: refute(page =~ name, "#{name} on the home page")
  end

  test "no demo slot, clip or demo images left" do
    html = home()
    assert count(html, "#demo, #demo-video, #demo-transcript") == 0
    refute File.exists?(Path.join([:code.priv_dir(:maya), "static", "images", "demo"]))
  end

  test "footer links the factory, the repo and its README, with inline art" do
    html = home()
    hrefs = attrs(html, "#site-footer a", "href")

    for href <- [
          "/factory",
          "https://github.com/darth-dodo/maya",
          "https://github.com/darth-dodo/maya#readme"
        ],
        do: assert(href in hrefs, href)

    svg = query(html, "#site-footer svg")
    refute Enum.empty?(svg)

    assert LazyHTML.attribute(svg, "aria-hidden") == ["true"] or
             not Enum.empty?(LazyHTML.query(svg, "title"))
  end
end
