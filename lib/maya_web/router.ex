defmodule MayaWeb.Router do
  use MayaWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MayaWeb.Layouts, :root}
    plug :protect_from_forgery
    # Strict CSP. The sha256 is the inline theme script in root.html.heex: edit that
    # script and the CSP test fails until this hash is updated.
    plug :put_secure_browser_headers, %{
      "content-security-policy" =>
        "default-src 'self'; " <>
          "script-src 'self' 'sha256-BK52NP1e8rQFFVZCoDYB4YoCL0cZc/KAVl4dkMM7/QM='; " <>
          "style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; " <>
          "connect-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; " <>
          "frame-ancestors 'none'"
    }
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", MayaWeb do
    get "/health", HealthController, :show
    get "/health/version", HealthController, :version
  end

  scope "/", MayaWeb do
    pipe_through :browser

    live "/", TalkLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", MayaWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:maya, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MayaWeb.Telemetry
    end
  end
end
