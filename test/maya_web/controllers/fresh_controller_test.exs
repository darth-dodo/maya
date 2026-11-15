defmodule MayaWeb.FreshControllerTest do
  use MayaWeb.ConnCase, async: true

  alias Maya.Voice.Turn

  test "Start fresh gives the browser a new guest; the old guest's turns stay stored", %{
    conn: conn
  } do
    {:ok, _} = Turn.insert(%Turn{guest_id: "guest-a", question: "Where is Ralts", answer: "102"})
    conn = conn |> init_test_session(guest_id: "guest-a") |> post(~p"/fresh")

    assert redirected_to(conn) == ~p"/"
    fresh = get_session(conn, :guest_id)
    assert fresh =~ ~r/\A[A-Za-z0-9_-]{22}\z/

    conn = get(recycle(conn), ~p"/")
    assert get_session(conn, :guest_id) == fresh
    refute html_response(conn, 200) =~ "Where is Ralts"
    assert [%Turn{question: "Where is Ralts"}] = Turn.recent("guest-a")
  end
end
