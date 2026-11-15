defmodule MayaWeb.BasicAuthTest do
  use MayaWeb.ConnCase, async: true

  # The Talk screen and Start fresh spend API credit, so they need the one login.
  # Health checks and static files stay open for Render and the browser.
  # The signed-in LiveView connect is covered by TalkLiveTest: its live(conn, ~p"/")
  # calls go through the router with ConnCase's login (it needs the shared sandbox).

  defp signed_out(conn), do: delete_req_header(conn, "authorization")

  test "Talk screen without credentials is refused with a Basic auth challenge", %{conn: conn} do
    conn = conn |> signed_out() |> get(~p"/")
    assert conn.status == 401
    assert [challenge] = get_resp_header(conn, "www-authenticate")
    assert challenge =~ "Basic"
    refute conn.resp_body =~ "talk-screen"
  end

  test "Start fresh without credentials is refused", %{conn: conn} do
    conn = conn |> signed_out() |> post(~p"/fresh")
    assert conn.status == 401
  end

  test "Talk screen with a wrong password is refused", %{conn: conn} do
    creds = Application.fetch_env!(:maya, :basic_auth)

    conn =
      conn
      |> put_req_header(
        "authorization",
        Plug.BasicAuth.encode_basic_auth(creds[:username], "wrong")
      )
      |> get(~p"/")

    assert conn.status == 401
  end

  test "Talk screen with the configured login renders", %{conn: conn} do
    assert conn |> get(~p"/") |> html_response(200) =~ "talk-screen"
  end

  test "health checks and static files stay open without credentials", %{conn: conn} do
    conn = signed_out(conn)

    for path <- [
          "/health",
          "/health/version",
          "/robots.txt",
          "/manifest.webmanifest",
          "/images/icon-192.png"
        ] do
      assert conn |> get(path) |> response(200), path
    end
  end
end
