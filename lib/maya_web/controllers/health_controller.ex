defmodule MayaWeb.HealthController do
  use MayaWeb, :controller

  # Render's health check: stays cheap and skips the DB so a paused database does not restart the app.
  def show(conn, _params), do: text(conn, "ok")

  # RENDER_GIT_COMMIT, read in config/runtime.exs; the post-deploy check polls this.
  def version(conn, _params), do: text(conn, Application.get_env(:maya, :git_commit, "unknown"))
end
