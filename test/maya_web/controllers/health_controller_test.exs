defmodule MayaWeb.HealthControllerTest do
  # Not async: the version tests change the global RENDER_GIT_COMMIT env var.
  use MayaWeb.ConnCase, async: false

  # Scenarios from openspec/specs/service-health/spec.md

  test "GET /health answers 200 ok without a session or the browser pipeline", %{conn: conn} do
    conn = get(conn, ~p"/health")

    assert text_response(conn, 200) == "ok"
    refute Map.has_key?(conn.resp_cookies, "_maya_key")
  end

  describe "GET /health/version" do
    setup do
      previous = System.get_env("RENDER_GIT_COMMIT")

      on_exit(fn ->
        if previous,
          do: System.put_env("RENDER_GIT_COMMIT", previous),
          else: System.delete_env("RENDER_GIT_COMMIT")
      end)
    end

    test "answers the deployed commit", %{conn: conn} do
      System.put_env("RENDER_GIT_COMMIT", "abc123")

      conn = get(conn, ~p"/health/version")

      assert text_response(conn, 200) == "abc123"
      refute Map.has_key?(conn.resp_cookies, "_maya_key")
    end

    test "answers unknown when no commit is available", %{conn: conn} do
      System.delete_env("RENDER_GIT_COMMIT")

      conn = get(conn, ~p"/health/version")

      assert text_response(conn, 200) == "unknown"
    end
  end
end
