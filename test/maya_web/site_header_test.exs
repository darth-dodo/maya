defmodule MayaWeb.SiteHeaderTest do
  # No database: / and /factory read none, and the /talk header is rendered from Layouts.app/1.
  # The /talk page itself is covered in talk_screen_page_test.exs.
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest, only: [rendered_to_string: 1]
  use MayaWeb, :verified_routes

  @endpoint MayaWeb.Endpoint

  # Scenarios from openspec/changes/tide-header/specs/site-header/spec.md

  defp page(path), do: build_conn() |> get(path) |> html_response(200)

  defp talk_header do
    rendered_to_string(MayaWeb.Layouts.app(%{flash: %{}, link: :home, inner_block: []}))
  end

  defp query(html, selector), do: html |> LazyHTML.from_document() |> LazyHTML.query(selector)
  defp count(html, selector), do: html |> query(selector) |> Enum.count()
  defp text_of(html, selector), do: html |> query(selector) |> LazyHTML.text() |> String.trim()
  defp attrs(html, selector, name), do: html |> query(selector) |> LazyHTML.attribute(name)

  # One CSS rule's body from app.css, by its exact selector.
  defp rule(selector) do
    css = File.read!("assets/css/app.css")
    [_, body] = Regex.run(~r/(?:^|\n)#{Regex.escape(selector)} \{([^}]*)\}/, css)
    body
  end

  defp theme_script do
    [script] = page(~p"/") |> query("head script:not([src])") |> Enum.map(&LazyHTML.text/1)
    script
  end

  describe "one shared header" do
    test "header parts on /, /factory and the Talk layout" do
      for html <- [page(~p"/"), page(~p"/factory"), talk_header()] do
        assert count(html, "header") == 1
        assert count(html, "#site-header") == 1
        assert text_of(html, "#site-header a.site-wordmark[href='/']") == "Maya"
        assert count(html, "#site-header a.header-link") == 1
        assert count(html, "#site-header #theme-toggle") == 1
      end
    end

    test "wordmark in the heading font, fixed header height and padding" do
      assert rule(".site-wordmark") =~ "font-family: var(--maya-font-head)"
      assert rule(".site-header") =~ "min-height: 3.5rem"
      assert rule(".site-header") =~ "padding: 0.5rem 1rem"
    end
  end

  describe "header link per page" do
    test "Talk on / and /factory" do
      for html <- [page(~p"/"), page(~p"/factory")] do
        assert text_of(html, "#header-talk-link") == "Talk"
        assert attrs(html, "#header-talk-link", "href") == ["/talk"]
        assert count(html, "#header-home-link") == 0
      end
    end

    test "Home on the Talk layout" do
      html = talk_header()
      assert text_of(html, "#header-home-link") == "Home"
      assert attrs(html, "#header-home-link", "href") == ["/"]
      assert count(html, "#header-talk-link") == 0
    end

    test "link is at least 44px tall" do
      assert rule(".header-link") =~ "min-height: 2.75rem"
    end
  end

  describe "one-button theme toggle" do
    test "one plain button with both labelled states and hidden icons" do
      for html <- [page(~p"/"), page(~p"/factory"), talk_header()] do
        assert count(html, "button#theme-toggle[type='button']") == 1
        assert text_of(html, "#theme-toggle .theme-to-night .sr-only") == "Switch to night"
        assert text_of(html, "#theme-toggle .theme-to-day .sr-only") == "Switch to day"
        assert count(html, "#theme-toggle .theme-to-night .hero-moon[aria-hidden='true']") == 1
        assert count(html, "#theme-toggle .theme-to-day .hero-sun[aria-hidden='true']") == 1
        assert count(html, "[data-phx-theme]") == 0
        refute html |> query("#site-header") |> LazyHTML.to_html() =~ ~r/system/i
      end
    end

    test "CSS shows the moon by day and the sun at night, 44px, no border or background" do
      css = File.read!("assets/css/app.css")
      assert css =~ ~S|:root[data-theme="dark"] .theme-to-night { display: none; }|
      assert css =~ ~S|:root:not([data-theme="dark"]) .theme-to-day { display: none; }|

      toggle = rule(".theme-toggle")
      assert toggle =~ "min-width: 2.75rem"
      assert toggle =~ "min-height: 2.75rem"
      assert toggle =~ "border: 0"
      assert toggle =~ "background: transparent"
    end
  end

  describe "theme choice and first paint" do
    test "head script follows the phone, stores a tap and needs no socket" do
      script = theme_script()

      # One storage key, so visitors who chose before keep their choice.
      assert script =~ ~s("phx:theme")
      # Only light or dark count as a choice: a stored "system" is a first visit.
      assert script =~ ~s(t === "light" || t === "dark")
      assert script =~ "prefers-color-scheme: dark"
      assert script =~ ~S|addEventListener("storage"|
      # A plain delegated click listener, so / and /factory (no LiveView socket) work.
      assert script =~ ~S|document.addEventListener("click"|
      assert script =~ ~S|closest("#theme-toggle")|
      refute script =~ "phx:set-theme"
    end

    test "theme script runs in head before body" do
      html = page(~p"/")
      [head, _body] = String.split(html, "<body", parts: 2)
      assert head =~ ~s("phx:theme")
    end
  end
end
