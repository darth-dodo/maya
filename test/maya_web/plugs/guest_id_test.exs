defmodule MayaWeb.Plugs.GuestIdTest do
  use MayaWeb.ConnCase, async: true

  alias MayaWeb.Plugs.GuestId

  defp run(conn), do: conn |> fetch_session() |> GuestId.call(GuestId.init([]))

  test "a session with no guest gets a random 22 character url-safe id" do
    a = build_conn() |> init_test_session(%{}) |> run() |> get_session(:guest_id)
    b = build_conn() |> init_test_session(%{}) |> run() |> get_session(:guest_id)

    assert a =~ ~r/\A[A-Za-z0-9_-]{22}\z/
    assert a != b
  end

  test "a session with a guest keeps it" do
    conn = build_conn() |> init_test_session(guest_id: "guest-a") |> run()
    assert get_session(conn, :guest_id) == "guest-a"
  end

  test "the browser pipeline sets the guest once and the next request keeps it", %{conn: conn} do
    conn = get(conn, ~p"/talk")
    guest = get_session(conn, :guest_id)
    assert is_binary(guest)
    # Signed, and kept for a year so a closed phone browser keeps the guest.
    assert %{"_maya_key" => %{max_age: 31_536_000}} = conn.resp_cookies

    conn = get(recycle(conn), ~p"/talk")
    assert get_session(conn, :guest_id) == guest
  end
end
