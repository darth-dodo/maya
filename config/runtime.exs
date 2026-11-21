import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/maya start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :maya, MayaWeb.Endpoint, server: true
end

config :maya, MayaWeb.Endpoint, http: [port: String.to_integer(System.get_env("PORT", "4000"))]

# Commit Render deployed (set by Render per deploy); served by /health/version for the smoke check.
config :maya, :git_commit, System.get_env("RENDER_GIT_COMMIT", "unknown")

# Sentry (ADR-010): unset SENTRY_DSN sends nothing. Never in test, which collects with Sentry.Test.
config :sentry,
  dsn: if(config_env() != :test, do: System.get_env("SENTRY_DSN")),
  release: System.get_env("RENDER_GIT_COMMIT"),
  environment_name: to_string(config_env())

# Header token for POST /health/ask (the post-deploy Question). Unset turns the endpoint off.
config :maya, :smoke_token, System.get_env("SMOKE_TOKEN")

# Mistral key for STT and TTS. Missing means "voice is down" (Answers as text), not a boot failure.
if config_env() != :test do
  config :maya, :mistral, api_key: System.get_env("MISTRAL_API_KEY")
  # Agent key. Missing means every Answer is the spoken agent error line, not a boot failure.
  config :maya, :openrouter, api_key: System.get_env("OPENROUTER_API_KEY")
  # Realtime STT relay and live preview (ADR-009). Anything but "true" keeps batch STT only.
  config :maya, :voice, stt_realtime: System.get_env("MAYA_STT_REALTIME") == "true"
end

# Numbers-only LLM traces to Langfuse Cloud EU over OTLP/HTTP (ADR-010,
# https://langfuse.com/docs/opentelemetry/get-started). Either key unset: no exporter, no spans sent.
if config_env() != :test do
  case {System.get_env("LANGFUSE_PUBLIC_KEY"), System.get_env("LANGFUSE_SECRET_KEY")} do
    {public, secret} when public not in [nil, ""] and secret not in [nil, ""] ->
      config :opentelemetry, span_processor: :batch, traces_exporter: :otlp

      config :opentelemetry_exporter,
        otlp_protocol: :http_protobuf,
        otlp_traces_endpoint: "https://cloud.langfuse.com/api/public/otel/v1/traces",
        otlp_traces_headers: [
          {"Authorization", "Basic " <> Base.encode64(public <> ":" <> secret)},
          {"x-langfuse-ingestion-version", "4"}
        ]

    _unset ->
      config :opentelemetry, traces_exporter: :none
  end
end

if config_env() == :dev do
  # Reload browser tabs when matching files change.
  config :maya, MayaWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        # Static assets, except user uploads
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
        # Gettext translations
        ~r"priv/gettext/.*\.po$"E,
        # Router, Controllers, LiveViews and LiveComponents
        ~r"lib/maya_web/router\.ex$"E,
        ~r"lib/maya_web/(controllers|live|components)/.*\.(ex|heex)$"E
      ]
    ]
end

if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise """
      environment variable DATABASE_URL is missing.
      For example: ecto://USER:PASS@HOST/DATABASE
      """

  maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

  config :maya, Maya.Repo,
    # Supabase signs with its own public root CA (Database Settings > SSL Configuration).
    ssl: [cacertfile: Application.app_dir(:maya, "priv/certs/supabase-root-2021-ca.crt")],
    url: database_url,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
    # For machines with several cores, consider starting multiple pools of `pool_size`
    # pool_count: 4,
    socket_options: maybe_ipv6

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  # The session cookie needs 64+ bytes. Failing at boot keeps Render on the last good deploy
  # instead of going live and answering 500 on every page.
  if byte_size(secret_key_base) < 64 do
    raise "SECRET_KEY_BASE is #{byte_size(secret_key_base)} bytes, needs at least 64. Generate one with: mix phx.gen.secret"
  end

  # LiveView only accepts sockets from this host, so fall back to the hostname Render sets.
  host = System.get_env("PHX_HOST") || System.get_env("RENDER_EXTERNAL_HOSTNAME") || "example.com"

  config :maya, MayaWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://bandit.hexdocs.pm/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :maya, MayaWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://plug.hexdocs.pm/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :maya, MayaWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.
end
