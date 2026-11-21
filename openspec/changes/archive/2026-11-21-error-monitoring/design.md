# Design: error-monitoring

## Context

See proposal.md. Turns run in `Task.Supervisor.async_nolink` under `Maya.TaskSupervisor`, so a crash in the Agent or a stage reaches the Conversation as a `:DOWN` and the logger as an error report. Finch is already in the lock through Req.

## Decisions

1. **`sentry` 14.x** (14.0.1 on hex.pm, 2026-11-21). Default client `Sentry.FinchClient` since v12 ([Sentry options](https://hexdocs.pm/sentry/Sentry.html)), so no hackney. Recorded only when `:dsn` is set, per the same docs.
2. **Logger handler over Plug capture alone.** `Sentry.LoggerHandler` with level `:error` catches Task and GenServer crashes that never pass through a Plug; `Sentry.PlugCapture` covers controllers. LiveView errors come through the logger.
3. **Scrub in `before_send`, allow-list style.** Keep exception type, stack trace, release, environment and allowed tags; drop request data, user, extra and breadcrumbs messages over a short limit. Allow-list over deny-list, because a new field is safe by default.
4. **Breadcrumbs from warnings.** The handler records `:warning` as breadcrumbs (they ride on the next error), never as their own events, which keeps the 5k a month quota for real errors.

## Risks / Trade-offs

- [A crash report can carry state with a transcript] → `before_send` drops `extra` and long strings; a test crashes a turn holding a Question and asserts it is absent.
- [Quota of 5k errors a month] → Sentry drops past it; Maya keeps working.
- [Sentry outage] → events are sent async with retries; never on the turn path.

## Migration Plan

No data change. Rollback: unset `SENTRY_DSN`.
