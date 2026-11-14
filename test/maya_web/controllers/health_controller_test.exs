defmodule MayaWeb.HealthControllerTest do
  use MayaWeb.ConnCase, async: true

  test "GET /health answers 200 ok without a session or the browser pipeline", %{conn: conn} do
    conn = get(conn, ~p"/health")

    assert text_response(conn, 200) == "ok"
    refute Map.has_key?(conn.resp_cookies, "_maya_key")
  end
end
