defmodule Maya.ErrorMonitor do
  @moduledoc """
  Server side errors to Sentry, metadata only (ADR-010, spec error-monitoring).

  `attach/0` adds two logger handlers: `Sentry.LoggerHandler` turns crashes and error level
  messages into events, and this module turns each `Logger.warning` into a breadcrumb of the
  logging process (breadcrumbs are per process), never an event. `scrub/1` is the `before_send`:
  an allow-list that builds a new event from the exception type, stack frames without vars,
  release, environment, runtime contexts and the stage and reason tags; request data, user, extra
  and any string that quotes data or runs long never make it in. Off without `SENTRY_DSN`
  (Sentry sends nothing when its `:dsn` is unset).
  """

  alias Sentry.Interfaces.Stacktrace

  # shortcut: a quote means inspected data (a Question, an Answer, an id); plain interpolation of
  # content into an error string would pass, so lib/ keeps logging reasons only (LESSONS, #60).
  @limit 120
  @kept [
    :event_id,
    :timestamp,
    :level,
    :platform,
    :environment,
    :release,
    :dist,
    :sdk,
    :contexts,
    :server_name,
    :modules,
    :culprit,
    :source
  ]

  def attach do
    :logger.add_handler(:maya_sentry, Sentry.LoggerHandler, %{
      config: %{capture_level: :error, capture_log_messages: true}
    })

    :logger.add_handler(:maya_breadcrumbs, __MODULE__, %{level: :warning})
  end

  @doc false
  # :logger handler callback; it runs in the logging process, so the breadcrumb lands there.
  # A handler that raises is removed by :logger for good, hence the rescue.
  def log(%{level: :warning, msg: {:string, chardata}}, _config) do
    Sentry.Context.add_breadcrumb(%{
      category: "logger",
      level: "warning",
      message: IO.chardata_to_string(chardata)
    })
  rescue
    _ -> :ok
  end

  def log(_event, _config), do: :ok

  def scrub(%Sentry.Event{} = event) do
    struct!(
      Sentry.Event,
      event
      |> Map.take(@kept)
      |> Map.merge(%{
        tags: Map.take(event.tags, [:stage, :reason]),
        message:
          event.message &&
            %Sentry.Interfaces.Message{formatted: safe(event.message.formatted) || "(scrubbed)"},
        exception:
          Enum.map(
            event.exception,
            &%{&1 | value: safe(&1.value), stacktrace: frames(&1.stacktrace)}
          ),
        threads:
          event.threads && Enum.map(event.threads, &%{&1 | stacktrace: frames(&1.stacktrace)}),
        breadcrumbs:
          for(b <- event.breadcrumbs, msg = safe(b.message), do: %{b | message: msg, data: nil})
      })
    )
  end

  defp frames(%Stacktrace{frames: frames} = st) when is_list(frames),
    do: %{st | frames: Enum.map(frames, &%{&1 | vars: %{}})}

  defp frames(other), do: other

  defp safe(s) when is_binary(s) and byte_size(s) <= @limit,
    do: if(String.contains?(s, ["\"", "~c"]), do: nil, else: s)

  defp safe(_), do: nil
end
