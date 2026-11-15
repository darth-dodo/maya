defmodule MayaWeb.SiteMetadataTest do
  use MayaWeb.ConnCase, async: true

  # Scenarios from openspec/specs/site-metadata/spec.md

  @description "Maps, Answers, Yaps, Advice. A spoiler-free Pokémon Emerald companion."

  defp head(conn), do: conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()

  defp attr(doc, selector, name) do
    case doc |> LazyHTML.query(selector) |> LazyHTML.attribute(name) do
      [value] -> value
      other -> flunk("expected one #{selector}, got #{inspect(other)}")
    end
  end

  test "page metadata: title, description, theme colours and viewport", %{conn: conn} do
    doc = head(conn)

    assert doc |> LazyHTML.query("title") |> LazyHTML.text() |> String.trim() == "Maya"
    assert attr(doc, "meta[name='description']", "content") == @description
    assert attr(doc, "meta[name='viewport']", "content") =~ "viewport-fit=cover"

    assert attr(doc, "meta[name='theme-color'][media='(prefers-color-scheme: light)']", "content") =~
             ~r/^#[0-9a-f]{6}$/i

    assert attr(doc, "meta[name='theme-color'][media='(prefers-color-scheme: dark)']", "content") =~
             ~r/^#[0-9a-f]{6}$/i
  end

  test "iOS home screen tags and the manifest link", %{conn: conn} do
    doc = head(conn)

    assert attr(doc, "link[rel='apple-touch-icon']", "href") == "/images/apple-touch-icon.png"
    assert attr(doc, "link[rel='apple-touch-icon']", "sizes") == "180x180"
    assert attr(doc, "link[rel='manifest']", "href") == "/manifest.webmanifest"
    assert attr(doc, "meta[name='apple-mobile-web-app-capable']", "content") == "yes"
    assert attr(doc, "meta[name='mobile-web-app-capable']", "content") == "yes"
    assert attr(doc, "meta[name='apple-mobile-web-app-status-bar-style']", "content") != ""
    assert attr(doc, "meta[name='apple-mobile-web-app-title']", "content") == "Maya"

    assert attr(doc, "link[rel='icon'][type='image/png'][sizes='32x32']", "href") ==
             "/images/favicon-32.png"
  end

  test "link preview tags use absolute URLs from the configured host", %{conn: conn} do
    doc = head(conn)
    base = MayaWeb.Endpoint.url()

    assert attr(doc, "meta[property='og:title']", "content") == "Maya"
    assert attr(doc, "meta[property='og:description']", "content") == @description
    assert attr(doc, "meta[property='og:type']", "content") == "website"
    assert attr(doc, "meta[property='og:url']", "content") == base <> "/"
    assert attr(doc, "meta[property='og:image']", "content") == base <> "/images/og-image.png"
    assert attr(doc, "meta[property='og:image:width']", "content") == "1200"
    assert attr(doc, "meta[property='og:image:height']", "content") == "630"
    assert attr(doc, "meta[name='twitter:card']", "content") == "summary_large_image"
    assert attr(doc, "meta[name='twitter:image']", "content") == base <> "/images/og-image.png"
  end

  test "robots meta keeps the page out of search engines", %{conn: conn} do
    assert conn |> head() |> attr("meta[name='robots']", "content") == "noindex, nofollow"
  end

  test "manifest is served as JSON with the app fields and icons", %{conn: conn} do
    conn = get(conn, "/manifest.webmanifest")

    assert response(conn, 200)
    assert [type] = get_resp_header(conn, "content-type")
    assert type =~ "application/manifest+json"

    manifest = Jason.decode!(conn.resp_body)

    assert manifest["name"] == "Maya"
    assert manifest["short_name"] == "Maya"
    assert manifest["start_url"] == "/"
    assert manifest["display"] == "standalone"
    assert manifest["theme_color"] =~ ~r/^#[0-9a-f]{6}$/i
    assert manifest["background_color"] =~ ~r/^#[0-9a-f]{6}$/i

    icons = Enum.map(manifest["icons"], &{&1["sizes"], &1["purpose"] || "any"})
    assert {"192x192", "any"} in icons
    assert {"512x512", "any"} in icons
    assert {"512x512", "maskable"} in icons

    for icon <- manifest["icons"] do
      path = Path.join(:code.priv_dir(:maya), "static" <> icon["src"])
      assert File.exists?(path), "missing icon #{icon["src"]}"
    end
  end

  test "robots.txt disallows all", %{conn: conn} do
    body = conn |> get("/robots.txt") |> response(200)

    assert body =~ ~r/^User-agent: \*$/m
    assert body =~ ~r/^Disallow: \/$/m
  end
end
