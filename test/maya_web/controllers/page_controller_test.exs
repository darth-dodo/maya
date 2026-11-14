defmodule MayaWeb.PageControllerTest do
  use MayaWeb.ConnCase, async: true

  # Scenarios from openspec/specs/landing-page/spec.md

  @tagline "Maps, Answers, Yaps, Advice. Your spoiler-free Pokemon Emerald companion."

  defp home(conn), do: conn |> get(~p"/") |> html_response(200)

  defp text_of(html, selector) do
    html
    |> LazyHTML.from_document()
    |> LazyHTML.query(selector)
    |> LazyHTML.text()
    |> String.trim()
  end

  test "visitor opens the home page and sees Maya and the tagline", %{conn: conn} do
    html = home(conn)

    assert text_of(html, "h1") == "Maya"
    assert html =~ @tagline
  end

  test "generator content is gone from the home page", %{conn: conn} do
    html = home(conn)

    refute html =~ "Peace of mind from prototype to production"
    refute html =~ "Phoenix Framework"
    refute html =~ "github.com/phoenixframework"
  end

  test "browser tab title is Maya", %{conn: conn} do
    assert conn |> home() |> text_of("title") == "Maya"
  end
end
