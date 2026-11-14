# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :maya,
  ecto_repos: [Maya.Repo],
  generators: [timestamp_type: :utc_datetime]

# Voice loop (ARCHITECTURE.md 5). Models: https://docs.mistral.ai/studio/audio/specs-and-limits/audio-formats
config :maya, :voice,
  stt_model: "voxtral-mini-transcribe-3",
  tts_model: "voxtral-mini-tts-3-0",
  # Preset "Sky" (en_GB, female), chosen by ear 2026-11-14; ids from GET /v1/audio/voices.
  tts_voice: "01a135c4-d896-70d9-a498-2db10c5915ff",
  # Generated speech is mono at 24 kHz (Mistral audio formats page); the hook plays at this rate.
  tts_sample_rate: 24_000,
  stt_timeout_ms: 8_000,
  tts_timeout_ms: 8_000,
  # Agent model on OpenRouter with tool calling (ADR-007 picks it by measured agent ms).
  agent_model: "anthropic/claude-haiku-5.5",
  # The whole agent stage (up to 4 OpenRouter requests).
  agent_timeout_ms: 8_000

# Mistral HTTP client; the key is set in config/runtime.exs, tests stub with Req.Test.
config :maya, :mistral, base_url: "https://api.mistral.ai", req_options: []

# OpenRouter HTTP client for the agent; the key is set in config/runtime.exs, tests stub with Req.Test.
config :maya, :openrouter, base_url: "https://openrouter.ai/api", req_options: []

# Configure the endpoint
config :maya, MayaWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: MayaWeb.ErrorHTML, json: MayaWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Maya.PubSub,
  live_view: [signing_salt: "Bj5FaPAw"]

# Configure LiveView
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r"

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  maya: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.3",
  maya: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
