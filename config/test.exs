import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :maya, Maya.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "maya_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :maya, MayaWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "3KEhfrHkhiDvmxL+qWyQDd9JnyD7qnyI/XW4MkuVB2TEDTSKruevm2NW3OBb1CJ8",
  server: false

# Mistral calls never leave the test process (Req.Test stubs named Maya.Mistral).
config :maya, :mistral,
  base_url: "http://mistral.test",
  api_key: "test-key",
  req_options: [plug: {Req.Test, Maya.Mistral}, retry: false]

# OpenRouter calls never leave the test process (Req.Test stubs named Maya.OpenRouter).
config :maya, :openrouter,
  base_url: "http://openrouter.test",
  api_key: "test-key",
  req_options: [plug: {Req.Test, Maya.OpenRouter}, retry: false]

# No countdown unless a test sets one, so voice tests do not wait 2 s each.
config :maya, :voice, confirm_ms: 0

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
