defmodule MayaWeb.FontsTest do
  # No DB: static files and the home page only, so a plain ExUnit.Case over the endpoint.
  use ExUnit.Case, async: true

  import Phoenix.ConnTest

  @endpoint MayaWeb.Endpoint

  # Scenarios from openspec/specs/design-system/spec.md, "Self-hosted fonts"

  @fonts [
    "fraunces-latin-wght-normal.woff2",
    "fraunces-latin-wght-italic.woff2",
    "inter-latin-wght-normal.woff2"
  ]

  test "each font is served from self as font/woff2" do
    for font <- @fonts do
      conn = get(build_conn(), "/fonts/#{font}")

      assert conn.status == 200, font
      assert [type] = Plug.Conn.get_resp_header(conn, "content-type")
      assert type =~ "font/woff2"
    end
  end

  test "Fraunces italic is its own self-hosted face, not a synthesised slant" do
    css = File.read!("assets/css/app.css")

    assert css =~
             ~r/font-family: "Fraunces";\s*font-style: italic;[^}]*url\("\/fonts\/fraunces-latin-wght-italic\.woff2"\)/
  end

  test "a versioned font request is cached for a year" do
    conn = get(build_conn(), "/fonts/inter-latin-wght-normal.woff2?vsn=d")

    assert [cache] = Plug.Conn.get_resp_header(conn, "cache-control")
    assert cache =~ "max-age=31536000"
  end

  test "fonts load from self only: one Inter preload, no third party host, CSP font-src self" do
    conn = get(build_conn(), "/")
    doc = conn |> html_response(200) |> LazyHTML.from_document()

    assert [href] =
             doc
             |> LazyHTML.query("link[rel='preload'][as='font'][type='font/woff2'][crossorigin]")
             |> LazyHTML.attribute("href")

    assert href =~ ~r{^/fonts/inter-latin-wght-normal}

    for href <- doc |> LazyHTML.query("link[href], script[src]") |> attr_values(),
        do: assert(String.starts_with?(href, "/"), "third party asset: #{href}")

    refute File.read!("assets/css/app.css") =~ ~r{url\(\s*["']?(https?:)?//}

    assert [policy] = Plug.Conn.get_resp_header(conn, "content-security-policy")
    assert policy =~ "font-src 'self'"
  end

  defp attr_values(nodes),
    do: LazyHTML.attribute(nodes, "href") ++ LazyHTML.attribute(nodes, "src")
end
