defmodule MayaWeb.Plugs.GuestId do
  @moduledoc """
  Puts a random `guest_id` in the signed session cookie when it has none (ADR-008).
  Every guest's Conversation and Progress are keyed by it.
  """
  @behaviour Plug

  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    case get_session(conn, :guest_id) do
      nil -> put_session(conn, :guest_id, new_id())
      _kept -> conn
    end
  end

  @doc "16 random bytes as url-safe Base64 (22 characters)."
  def new_id, do: Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)
end
