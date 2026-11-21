# Tasks: llm-tracing

One build PR, size L. It says "Closes #N" and archives the change. If it passes 2x, cut the per-round token counts first (keep turn totals and tool spans).

## 0. Baseline

- [ ] 0.1 Before any change: agent-stage p50 and p95 from `mix maya.latency` (or 10 Questions on the phone). Verify: numbers saved for the PR body.

## 1. Deps and config

- [x] 1.1 Add `opentelemetry ~> 1.7`, `opentelemetry_api ~> 1.5`, `opentelemetry_exporter ~> 1.11`; `config/runtime.exs` sets the EU traces endpoint and Basic auth header when both keys are set, else `traces_exporter: :none`; test config collects spans in process. Verify: app starts with and without keys.
- [x] 1.2 `LANGFUSE_PUBLIC_KEY`, `LANGFUSE_SECRET_KEY` in render.yaml (`sync: false`), `.env.template` (names only), FACTORY.md secrets table. Verify: `grep LANGFUSE_` hits each.

## 2. Spans

- [x] 2.1 Turn, round and tool spans in `Maya.Agent`; completion tokens in the tally; one allow-list attribute helper. Verify: two round trace test, tool status test, timeout reason test, numbers match the log line.
- [x] 2.2 Privacy tests: no attribute holds the Question, Answer, guest id or tool arguments. Verify: tests green.
- [x] 2.3 Refused export port test: the turn answers normally. Verify: test green.

## 3. Live check, latency, docs

- [ ] 3.1 After deploy: one trace in Langfuse EU with rounds, tokens and tool spans. Verify: screenshot in the PR (Abhishek sets both keys).
- [ ] 3.2 Agent p50 and p95 after, next to 0.1, in the PR body; Answer p95 at most 8 s. Verify: numbers in the PR.
- [x] 3.3 ADR-010 Langfuse part shipped; CLAUDE.md frozen stack and `settled-architecture` list Langfuse; changelog fragment. Verify: `openspec validate --all --strict`, `mix precommit`, `mix credo` green.
