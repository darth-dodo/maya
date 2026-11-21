defmodule Maya.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MayaWeb.Telemetry,
      Maya.Repo,
      {Phoenix.PubSub, name: Maya.PubSub},
      # The voice loop (ARCHITECTURE.md 2): one Conversation per guest, found by name, its turn work in Tasks.
      {Registry, keys: :unique, name: Maya.ConversationRegistry},
      {DynamicSupervisor, name: Maya.ConversationSupervisor, strategy: :one_for_one},
      {Task.Supervisor, name: Maya.TaskSupervisor},
      # Start to serve requests, typically the last entry
      MayaWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    Maya.Voice.Timing.attach()
    Maya.ErrorMonitor.attach()
    opts = [strategy: :one_for_one, name: Maya.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MayaWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
