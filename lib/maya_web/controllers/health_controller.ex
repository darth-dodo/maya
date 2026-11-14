defmodule MayaWeb.HealthController do
  use MayaWeb, :controller

  # Render's health check: stays cheap and skips the DB so a paused database does not restart the app.
  def show(conn, _params), do: text(conn, "ok")
end
