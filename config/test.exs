import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
#
# A git worktree (its .git is a file, not a directory) gets its own database by default,
# named after the worktree folder, because the release test's migration DDL deadlocks a second
# run on a shared maya_test (#214). The main checkout and CI keep plain maya_test.
# shortcut: folder names equal after lowercasing, `_` for punctuation and 40 chars share a
# database, fine for `agent-<hex>` worktrees; add a path hash if real names collide.
root = Path.expand("..", __DIR__)

worktree_suffix =
  if File.regular?(Path.join(root, ".git")) do
    "_" <>
      (root
       |> Path.basename()
       |> String.downcase()
       |> String.replace(~r/[^a-z0-9]/, "_")
       |> String.slice(0, 40))
  end

config :maya, Maya.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "maya_test#{System.get_env("MIX_TEST_PARTITION", worktree_suffix)}",
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

# The batch processor as in prod, with no exporter unless a test sets one (Maya.Agent.TraceTest).
config :opentelemetry, span_processor: :batch, traces_exporter: :none

# No countdown unless a test sets one (#95), so the voice tests see a plain `{:question, text}`.
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
