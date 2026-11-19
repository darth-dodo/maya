defmodule Maya.Repo do
  use Ecto.Repo,
    otp_app: :maya,
    adapter: Ecto.Adapters.Postgres

  @doc """
  The errors of Postgres being down or paused, rescued by the Conversation, the agent's tools
  and the Talk screen (#82, #192). OwnershipError is also how tests take the pool away.
  """
  def outage_errors,
    do: [DBConnection.ConnectionError, DBConnection.OwnershipError, Postgrex.Error]
end
