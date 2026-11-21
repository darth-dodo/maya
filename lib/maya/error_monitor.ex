defmodule Maya.ErrorMonitor do
  @moduledoc """
  Server side errors to Sentry, metadata only (ADR-010, spec error-monitoring).

  `attach/0` adds two logger handlers: `Sentry.LoggerHandler` turns crashes at error level into
  events, and this module turns each `Logger.warning` into a breadcrumb of the logging process,
  never an event. `scrub/1` is the `before_send`: an allow-list that keeps the exception type,
  stack frames, release, environment and the stage and reason tags, and drops request data,
  user, extra, frame vars and any string that quotes data or runs long. Off without
  `SENTRY_DSN` (Sentry sends nothing when its `:dsn` is unset).
  """

  alias Sentry.Interfaces.{Request, Stacktrace}

  # Inspected terms quote their strings, so a quote means data (a Question, an Answer, an id).
  @limit 120

  def attach do
    :logger.add_handler(:maya_sentry, Sentry.LoggerHandler, %{config: %{capture_level: :error}})
    :logger.add_handler(:maya_breadcrumbs, __MODULE__, %{level: :warning})
  end

  @doc false
  # :logger handler callback; handlers run in the logging process, so the breadcrumb lands there.
  def log(%{level: :warning, msg: {:string, chardata}}, _config) do
    Sentry.Context.add_breadcrumb(%{
      category: "logger",
      level: "warning",
      message: IO.chardata_to_string(chardata)
    })
  end

  def log(_event, _config), do: :ok

  def scrub(%Sentry.Event{} = event) do
    %{
      event
      | request: %Request{},
        user: %{},
        extra: %{},
        fingerprint: [],
        attachments: [],
        tags: Map.take(event.tags, [:stage, :reason]),
        message:
          event.message &&
            %{
              event.message
              | message: nil,
                params: nil,
                formatted: safe(event.message.formatted) || "(scrubbed)"
            },
        exception:
          Enum.map(
            event.exception,
            &%{&1 | value: safe(&1.value), stacktrace: frames(&1.stacktrace)}
          ),
        threads:
          event.threads && Enum.map(event.threads, &%{&1 | stacktrace: frames(&1.stacktrace)}),
        breadcrumbs:
          for(b <- event.breadcrumbs, msg = safe(b.message), do: %{b | message: msg, data: nil})
    }
  end

  defp frames(%Stacktrace{frames: frames} = st) when is_list(frames),
    do: %{st | frames: Enum.map(frames, &%{&1 | vars: %{}})}

  defp frames(other), do: other

  defp safe(s) when is_binary(s) and byte_size(s) <= @limit,
    do: if(String.contains?(s, ["\"", "~c"]), do: nil, else: s)

  defp safe(_), do: nil
end
