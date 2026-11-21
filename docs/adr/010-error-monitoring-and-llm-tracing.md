# 010: Error monitoring and LLM tracing

- Status: Accepted (Sentry shipped in #87, Langfuse in `llm-tracing`, #216)
- Date: 2026-11-21 (Abhishek said yes to both services on 2026-11-21, free plans only, EU region where offered)

## Context
Production errors are found on the phone: #55 took a phone test and a pasted Render trace (#87). The agent loop logs one numbers-only line per Question (#212), but Render logs are short lived and cannot show which round, tool or model made a turn slow or wrong. Both services sit outside the frozen stack in CLAUDE.md, so they need this ADR.

## Decision
- **Errors: Sentry**, through the official `sentry` Hex package ([hexdocs](https://hexdocs.pm/sentry/Sentry.html)), server side only. Its default HTTP client is Finch, already in the lock through Req. Change `error-monitoring` (#87).
- **LLM traces: Langfuse Cloud, EU region** (`https://cloud.langfuse.com/api/public/otel`), through `opentelemetry`, `opentelemetry_api` and `opentelemetry_exporter` over OTLP/HTTP protobuf with Basic auth (public key : secret key). The legacy ingestion API was sunset on Cloud on 2026-11-16; OTLP is the supported path ([Langfuse OpenTelemetry](https://langfuse.com/docs/opentelemetry/get-started)). Change `llm-tracing`.

## Privacy
Metadata only, for both. Nothing that a Guest said or heard leaves the app: no audio, Question, Answer, transcript, system prompt, history, tool arguments or results, Progress, cookies, headers, guest ids or keys.
- Sentry: a `before_send` strips request bodies, LiveView event params, cookies, headers and long strings; tags are stage and reason atoms only.
- Langfuse: span attributes are numbers, the model id, tool names and status atoms only. A test asserts no attribute holds Question or Answer text.

## Cost
Free plans only; any paid tier needs a new ask.
- Sentry Developer: 5k errors a month, 1 user, 30 day lookback ([pricing](https://sentry.io/pricing/)).
- Langfuse Hobby: 50k units a month, 30 day data access, 2 users, no card ([pricing](https://langfuse.com/pricing)).
Past a quota the service drops data; Maya keeps working.

## How to turn each off
- Sentry: unset `SENTRY_DSN`. No events are sent (the default in dev, test and CI).
- Langfuse: unset `LANGFUSE_PUBLIC_KEY` or `LANGFUSE_SECRET_KEY`. No spans are exported (the default in dev, test and CI).

## Consequences
- Easier: errors arrive with stack trace and commit; slow or failed turns can be read per round and tool.
- Harder: four new dependencies (the OTel exporter also pulls `grpcbox` and `tls_certificate_check`); two more secrets on Render.
- Check: export is async (the batch span processor) and never adds agent latency; agent p50 and p95 before and after in the `llm-tracing` build PR.
- The frozen stack table in CLAUDE.md and the `settled-architecture` skill changes in each build PR, not in the spec PR. This ADR becomes Accepted in the first of the two build PRs to ship; the second notes its part as shipped.
