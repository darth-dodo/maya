defmodule MayaWeb.ContentSecurityPolicyTest do
  use MayaWeb.ConnCase, async: true

  # Scenarios from openspec/specs/web-security/spec.md

  defp home(conn) do
    conn = get(conn, ~p"/")
    [policy] = get_resp_header(conn, "content-security-policy")
    {policy, html_response(conn, 200)}
  end

  defp directive(policy, name) do
    policy
    |> String.split(";")
    |> Enum.map(&String.trim/1)
    |> Enum.find("", &String.starts_with?(&1, name <> " "))
  end

  test "header present with the core directives", %{conn: conn} do
    {policy, _html} = home(conn)

    assert policy =~ "default-src 'self'"
    assert policy =~ "object-src 'none'"
    assert policy =~ "frame-ancestors 'none'"
  end

  test "every inline script is allowed only by its hash", %{conn: conn} do
    {policy, html} = home(conn)
    script_src = directive(policy, "script-src")

    inline_scripts =
      html
      |> LazyHTML.from_document()
      |> LazyHTML.query("script:not([src])")
      |> Enum.map(&LazyHTML.text/1)

    assert inline_scripts != []

    for script <- inline_scripts do
      hash = :crypto.hash(:sha256, script) |> Base.encode64()
      assert script_src =~ "'sha256-#{hash}'", "inline script not covered by script-src"
    end

    refute script_src =~ "'unsafe-inline'"
    refute script_src =~ "'unsafe-eval'"
  end

  test "policy names no third-party origins", %{conn: conn} do
    {policy, _html} = home(conn)

    # Beyond 'self' and 'none': data: only for images, 'unsafe-inline' only for styles,
    # sha256 hashes only for scripts.
    extra = %{"img-src" => ["data:"], "style-src" => ["'unsafe-inline'"]}

    for directive <- String.split(policy, ";", trim: true) do
      [name | sources] = String.split(directive)

      for source <- sources do
        script_hash? = name == "script-src" and String.starts_with?(source, "'sha256-")

        assert source in ["'self'", "'none'" | Map.get(extra, name, [])] or script_hash?,
               "unexpected source #{source} in #{name}"
      end
    end
  end
end
