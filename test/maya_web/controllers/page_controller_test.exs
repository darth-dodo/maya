defmodule MayaWeb.PageControllerTest do
  use MayaWeb.ConnCase, async: true

  # Scenarios from openspec/specs/landing-page/spec.md

  @tagline "Maps, Answers, Yaps, Advice. Your spoiler-free Pokemon Emerald companion."
  @leaders ~w(Roxanne Brawly Wattson Flannery Norman Winona Tate Liza Juan)
  @badges ~w(Stone Knuckle Dynamo Heat Balance Feather Mind Rain)

  defp home(conn), do: conn |> get(~p"/") |> html_response(200)

  defp doc(html), do: LazyHTML.from_document(html)

  defp text_of(html, selector) do
    html |> doc() |> LazyHTML.query(selector) |> LazyHTML.text() |> String.trim()
  end

  defp count(html, selector), do: html |> doc() |> LazyHTML.query(selector) |> Enum.count()

  defp attrs(html, selector, name),
    do: html |> doc() |> LazyHTML.query(selector) |> LazyHTML.attribute(name)

  test "visitor opens the home page and sees Maya and the tagline", %{conn: conn} do
    html = home(conn)

    assert text_of(html, "h1") == "Maya"
    assert html =~ @tagline
    assert text_of(html, "#maya-heading") == "Maya"
    assert text_of(html, "#tagline") == @tagline
  end

  test "generator content is gone from the page and its layout", %{conn: conn} do
    html = home(conn)

    # The page must use the app layout, so this test covers its header too.
    assert count(html, "header") == 1
    refute html =~ "Peace of mind from prototype to production"
    refute html =~ "Phoenix Framework"
    refute html =~ "github.com/phoenixframework"
    refute html =~ "phoenixframework.org"
    refute html =~ "hexdocs.pm"
  end

  test "browser tab title is Maya", %{conn: conn} do
    assert conn |> home() |> text_of("title") == "Maya"
  end

  test "Poke Ball is present and drawn without images", %{conn: conn} do
    html = home(conn)

    assert count(html, "#pokeball") == 1
    assert count(html, "#pokeball img") == 0
  end

  test "Mudkip hype line", %{conn: conn} do
    assert conn |> home() |> text_of("#mudkip-hype") ==
             "Mudkip hype: 100. Best starter, no debate."
  end

  test "badge case has eight empty numbered slots", %{conn: conn} do
    html = home(conn)

    assert count(html, "#badge-case .badge-slot") == 8
    assert attrs(html, "#badge-case .badge-slot", "data-earned") == List.duplicate("false", 8)

    assert attrs(html, "#badge-case .badge-slot", "aria-label") ==
             Enum.map(1..8, &"Badge #{&1} of 8")
  end

  test "no spoilers: no gym leader or badge names", %{conn: conn} do
    html = home(conn)

    for name <- @leaders, do: refute(html =~ name, "leader #{name} on the page")
    for name <- @badges, do: refute(html =~ "#{name} Badge", "#{name} Badge on the page")
  end

  test "only own assets and no img elements", %{conn: conn} do
    html = home(conn)
    refs = attrs(html, "[src]", "src") ++ attrs(html, "link[rel=stylesheet]", "href")

    assert refs != []

    for ref <- refs,
        do: assert(String.starts_with?(ref, "/") and not String.starts_with?(ref, "//"), ref)

    assert count(html, "img") == 0
  end
end
