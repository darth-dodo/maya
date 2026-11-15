defmodule MayaWeb.FreshController do
  @moduledoc """
  Start fresh (ADR-008): a LiveView cannot write the session cookie, so the Talk screen's
  confirm form posts here. The browser gets a new guest; the old guest's rows stay.
  """
  use MayaWeb, :controller

  alias MayaWeb.Plugs.GuestId

  def create(conn, _params) do
    conn
    |> put_session(:guest_id, GuestId.new_id())
    |> redirect(to: ~p"/talk")
  end
end
