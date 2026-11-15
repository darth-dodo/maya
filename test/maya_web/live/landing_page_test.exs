defmodule MayaWeb.LandingPageTest do
  use MayaWeb.ConnCase, async: true

  alias Maya.Voice.Turn

  # Scenarios from openspec/specs/landing-page/spec.md, on the Talk screen's first (dead) render.

  # Roxanne is a new Guest's Next gym, inside the Spoiler horizon; these come after her.
  @later_leaders ~w(Brawly Wattson Flannery Norman Winona Tate Liza Juan)
  @badges ~w(Stone Knuckle Dynamo Heat Balance Feather Mind Rain)

  defp home(conn), do: conn |> get(~p"/") |> html_response(200)

  defp doc(html), do: LazyHTML.from_document(html)

  defp text_of(html, selector) do
    html |> doc() |> LazyHTML.query(selector) |> LazyHTML.text() |> String.trim()
  end

  defp count(html, selector), do: html |> doc() |> LazyHTML.query(selector) |> Enum.count()

  defp attrs(html, selector, name),
    do: html |> doc() |> LazyHTML.query(selector) |> LazyHTML.attribute(name)

  test "visitor opens the home page and sees Maya once, with one hidden h1", %{conn: conn} do
    html = home(conn)

    assert text_of(html, "header a[href='/']") == "Maya"
    assert count(html, "h1") == 1
    assert text_of(html, "h1#talk-heading.sr-only") == "Talk to Maya"
    assert count(html, "#maya-heading") == 0
    assert count(html, "#tagline") == 0
  end

  test "generator content is gone from the page and its layout", %{conn: conn} do
    html = home(conn)

    # The page must use the app layout, so this test covers its header too.
    assert count(html, "header") == 1
    assert text_of(html, "header a[href='/']") == "Maya"
    assert count(html, "header [data-phx-theme]") == 3
    refute html =~ to_string(Application.spec(:phoenix, :vsn))
    refute html =~ "Peace of mind from prototype to production"
    refute html =~ "Phoenix Framework"
    refute html =~ "github.com/phoenixframework"
    refute html =~ "phoenixframework.org"
    refute html =~ "hexdocs.pm"
  end

  test "browser tab title is Maya", %{conn: conn} do
    assert conn |> home() |> text_of("title") == "Maya"
  end

  test "Poké Ball is present and drawn without images", %{conn: conn} do
    html = home(conn)

    assert count(html, "#pokeball") == 1
    assert count(html, "#pokeball img") == 0
  end

  test "Emerald ball sits in the trainer card and the old hero is gone", %{conn: conn} do
    html = home(conn)

    assert attrs(html, "#trainer-card #pokeball", "class") |> hd() =~ "pokeball-emerald"
    assert count(html, "#maya-hero") == 0
  end

  test "all three backdrops are served from Maya's own origin", %{conn: conn} do
    for name <- ~w(tide dusk night) do
      conn = get(conn, "/images/backdrops/#{name}.jpg")
      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> hd() =~ "image/jpeg"
    end
  end

  test "badge case in the trainer card has eight empty numbered slots", %{conn: conn} do
    html = home(conn)

    assert count(html, "#trainer-card #badge-case .badge-slot") == 8
    assert attrs(html, "#badge-case .badge-slot", "data-earned") == List.duplicate("false", 8)

    assert attrs(html, "#badge-case .badge-slot", "aria-label") ==
             Enum.map(1..8, &"Badge #{&1} of 8")
  end

  test "no spoilers: the Next gym only, and no badge names", %{conn: conn} do
    html = home(conn)

    assert text_of(html, "#next-gym strong") == "Next gym: Roxanne"
    for name <- @later_leaders, do: refute(html =~ name, "leader #{name} on the page")
    for name <- @badges, do: refute(html =~ "#{name} Badge", "#{name} Badge on the page")
  end

  test "Poké facts: 10 to 14 non-empty facts", %{conn: conn} do
    facts = conn |> home() |> doc() |> LazyHTML.query("#poke-facts .poke-fact")

    assert Enum.count(facts) in 10..14

    for fact <- facts,
        do: assert(fact |> LazyHTML.text() |> String.trim() != "", "empty .poke-fact")
  end

  test "Poké facts never name an evolved Hoenn starter", %{conn: conn} do
    facts = conn |> home() |> text_of("#poke-facts")

    assert facts =~ "Mudkip"

    for name <- ~w(Grovyle Sceptile Combusken Blaziken Marshtomp Swampert),
        do: refute(facts =~ name, "#{name} in the Poké facts")
  end

  test "no script in the page content", %{conn: conn} do
    assert conn |> home() |> count("main script") == 0
  end

  test "only own assets and no img elements", %{conn: conn} do
    html = home(conn)
    refs = attrs(html, "[src]", "src") ++ attrs(html, "link[rel=stylesheet]", "href")

    assert refs != []

    for ref <- refs,
        do: assert(String.starts_with?(ref, "/") and not String.starts_with?(ref, "//"), ref)

    assert count(html, "img") == 0
  end

  test "Poké facts hide once the Conversation has a turn; the badge case stays", %{conn: conn} do
    {:ok, _} =
      Turn.insert(%Turn{guest_id: "landing", question: "Where is Ralts", answer: "Route 102"})

    html = conn |> Plug.Test.init_test_session(guest_id: "landing") |> home()

    assert count(html, "#badge-case") == 1
    assert count(html, "#poke-facts") == 0
    assert text_of(html, "#conversation .turn .question") == "Where is Ralts"
    assert text_of(html, "#conversation .turn .answer") == "Route 102"
  end
end
