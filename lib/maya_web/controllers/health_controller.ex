defmodule MayaWeb.HealthController do
  use MayaWeb, :controller

  # Render's health check: stays cheap and skips the DB so a paused database does not restart the app.
  def show(conn, _params), do: text(conn, "ok")

  # Read at request time: Render sets RENDER_GIT_COMMIT per deploy; the post-deploy check polls this.
  def version(conn, _params), do: text(conn, System.get_env("RENDER_GIT_COMMIT", "unknown"))
end
