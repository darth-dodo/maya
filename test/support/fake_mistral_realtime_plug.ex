defmodule Maya.FakeMistralRealtimePlug do
  @moduledoc "Upgrades to `Maya.FakeMistralRealtime`, reporting the request to the test; `:unauthorized` answers 401."
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, %{mode: :unauthorized}), do: send_resp(conn, 401, "")

  def call(conn, opts) do
    conn = fetch_query_params(conn)

    send(
      opts.test,
      {:fake_request,
       %{
         path: conn.request_path,
         model: conn.query_params["model"],
         auth: get_req_header(conn, "authorization")
       }}
    )

    conn |> WebSockAdapter.upgrade(Maya.FakeMistralRealtime, opts, []) |> halt()
  end
end
