# Design: llm-tracing

## Context

See proposal.md. `Maya.Agent.answer/3` runs in a turn Task; rounds and tool calls run in that same process (`loop/6`, `tool_message/2`), so the OpenTelemetry process context carries parent spans with no passing. `tally/2` already sums prompt and cached tokens per turn for the log line.

## Decisions

1. **Deps, versions on hex.pm on 2026-11-21**: `opentelemetry` 1.7.0, `opentelemetry_api` 1.5.0, `opentelemetry_exporter` 1.11.0. The exporter requires `opentelemetry ~> 1.7.0`, `opentelemetry_api ~> 1.5.0`, `grpcbox` and `tls_certificate_check ~> 1.18` (hex.pm release metadata). No separate protobuf dep: the exporter ships the OTLP protobuf modules and defaults to `http_protobuf` ([exporter README](https://hexdocs.pm/opentelemetry_exporter/readme.html)). Langfuse takes OTLP over HTTP (JSON or protobuf), not gRPC.
2. **Exporter config in `config/runtime.exs`**: `otlp_traces_endpoint` the full EU traces URL (path kept as is), `otlp_traces_headers` `Authorization: Basic base64(public:secret)` and `x-langfuse-ingestion-version: 4` (Langfuse docs). Keys unset: `traces_exporter: :none`.
3. **Async by default**: the SDK's batch span processor queues ended spans and exports from its own process; a full queue drops spans. Nothing in the turn waits on the network.
4. **Attribute names**: GenAI semantic conventions Langfuse maps (`gen_ai.request.model`, `gen_ai.usage.input_tokens`, `gen_ai.usage.output_tokens`) plus `maya.*` for the rest (`maya.rounds`, `maya.cached_tokens`, `maya.tool.status`, `maya.honesty`, `maya.reason`). Only atoms, integers and the model id string.
5. **Allow-list helper**: one function builds every attribute map from the turn tally, a tool name and an atom; no call site passes raw strings. Unknown outcomes map to `error`.
6. **Tests**: `otel_simple_processor` with the test pid exporter collects spans; a test answers a Question with known text and asserts no attribute value contains it.

## Risks / Trade-offs

- [A future attribute leaks content] → the allow-list helper and the no-text test.
- [Export failure or Langfuse outage] → the batch processor logs and drops; the turn is never on that path. A test points the exporter at a refused port and asserts the turn answers.
- [Hobby quota of 50k units a month] → about 1 + rounds + tool calls units per Question; past the quota Langfuse drops data.
- [Four new deps in a 512 MB container] → check memory on Render after deploy.

## Migration Plan

No data change. Rollback: unset either key.
