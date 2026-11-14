defmodule MayaWeb.HealthControllerTest do
  # Not async: the version tests change the global :git_commit app env.
  use MayaWeb.ConnCase, async: false

  # Scenarios from openspec/specs/service-health/spec.md

  test "GET /health answers 200 ok without a session or the browser pipeline", %{conn: conn} do
    conn = get(conn, ~p"/health")

    assert text_response(conn, 200) == "ok"
    refute Map.has_key?(conn.resp_cookies, "_maya_key")
  end

  describe "GET /health/version" do
    setup do
      previous = Application.fetch_env(:maya, :git_commit)

      on_exit(fn ->
        case previous do
          {:ok, value} -> Application.put_env(:maya, :git_commit, value)
          :error -> Application.delete_env(:maya, :git_commit)
        end
      end)
    end

    test "answers the deployed commit", %{conn: conn} do
      Application.put_env(:maya, :git_commit, "abc123")

      conn = get(conn, ~p"/health/version")

      assert text_response(conn, 200) == "abc123"
      refute Map.has_key?(conn.resp_cookies, "_maya_key")
    end

    test "answers unknown when no commit is available", %{conn: conn} do
      Application.delete_env(:maya, :git_commit)

      conn = get(conn, ~p"/health/version")

      assert text_response(conn, 200) == "unknown"
    end
  end
end
