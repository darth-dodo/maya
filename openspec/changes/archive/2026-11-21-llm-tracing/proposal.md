# Proposal: llm-tracing

## Why

The agent stage is the largest share of Answer time and the place where Answers go wrong, but today the only record is one numbers-only log line per Question (#212) that Render keeps briefly. Abhishek approved Langfuse on 2026-11-21 (free Hobby plan, EU region) to see each turn per round and per tool. Decision, privacy and cost: ADR-010.

## What Changes

- **One trace per Question** to Langfuse Cloud EU over OTLP/HTTP (`https://cloud.langfuse.com/api/public/otel/v1/traces`, Basic auth public key : secret key), using `opentelemetry`, `opentelemetry_api` and `opentelemetry_exporter` (Abhishek's choice over hand-rolled Req). The legacy ingestion API was sunset on Cloud on 2026-11-16 ([Langfuse OpenTelemetry](https://langfuse.com/docs/opentelemetry/get-started)).
- **Spans**: a turn span, one span per round (completion request) and one per tool call.
- **Data rule (Abhishek's choice): numbers and tool names only.** Model id, rounds, tool names, tool status atoms (`ok`, `not_found`, `past_horizon`, `error`), prompt, cached and completion tokens, latency per span, the honesty check outcome and error reason atoms. Never the Question, Answer, system prompt, history, tool arguments or results, Progress, guest id or keys.
- **Source of numbers**: the per-turn tally behind the turn log line (#212), plus completion tokens.
- **Off when unset**: no export unless both `LANGFUSE_PUBLIC_KEY` and `LANGFUSE_SECRET_KEY` are set (dev, test, CI). Export is async and a failed export never slows or crashes a turn.
- **Config**: both names in render.yaml (`sync: false`), `config/runtime.exs`, `.env.template` (names only), the FACTORY.md secrets table.
- **Docs**: ADR-010 Langfuse part shipped; the frozen stack in CLAUDE.md and `settled-architecture` list Langfuse.

Size: L (one build PR).

Out of scope: tracing STT, TTS or the realtime relay; Langfuse prompt management, evals, scores or datasets; any content in spans; a self-hosted Langfuse; any paid plan. Each is a PHASE_2.md line if wanted.

## Capabilities

### New Capabilities

- `llm-tracing`: a numbers-only Langfuse trace per Question.

### Modified Capabilities

None. The turn log line (agent spec) stays as it is.

## Impact

- Code: `mix.exs` (3 deps), `config/runtime.exs`, `config/test.exs`, `lib/maya/agent.ex` (spans around the loop, rounds and tool calls; completion tokens in the tally), tests.
- Config: render.yaml, `.env.template`, FACTORY.md, CLAUDE.md, `settled-architecture`.
- Voice loop: span creation in the agent Task; export in the batch processor's own process. Agent p50 and p95 before and after.
- Issue: to be filed after this spec PR (factory:plan step 6).
