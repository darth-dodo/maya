# Tasks: structured-answers

One build PR, 2h, "Closes #118".

## 1. Check first

- [ ] 1.1 With `OPENROUTER_API_KEY` set, send three requests to the configured `agent_model` with `tools`, the `answer` `response_format` and `provider.require_parameters` true: one that needs `gym_counter`, its follow-up with the tool message, and one chat Question. Verify: the first returns `tool_calls`, the other two return schema JSON in `content`; record the result in the PR. If the model cannot do both, stop and ask Abhishek (design, first decision).

## 2. Structured Answer

- [x] 2.1 `Maya.Agent.Answer`: embedded schema, changeset and the claim word list (moved from `test/fixtures/spoiler_probes.json`). Verify: `mix test test/maya/agent/answer_test.exs` for valid, missing `answer`, empty `answer`, plain text, and each claim word.
- [x] 2.2 Request body gains `response_format` and `provider.require_parameters`; the loop parses `content` through `Answer` and returns only `answer`. Verify: the Roxanne round trip test asserts both fields in both requests and the Answer text.

## 3. Honesty check

- [x] 3.1 Reject on an unknown id or an unbacked claim; one corrective request inside the 4-request cap and the deadline; the fallback line after a second rejection or with no request or time left. Verify: agent tests for the Ralts claim (corrected, and fallback), `call_9`, a `log_event` confirm that passes, and two rejections making no third request.
- [x] 3.2 Prompt rule for the schema, `used_tool_calls` and never claiming a tool result not returned this turn. Verify: prompt test, no "beat" or "defeat".
- [x] 3.3 The honesty probe in `test/maya/spoiler_gate_test.exs` runs through the loop with the model stubbed and ends corrected or replaced. Verify: `mix test --only spoiler_gate`.

## 4. Latency and docs

- [ ] 4.1 10 Questions on the phone before and after: agent-stage p50 and p95 from `mix maya.latency`, the corrective request count, and the Ralts Question said out loud. Verify: numbers and a screenshot in the PR; Answer time p95 at most 8 s.
- [x] 4.2 ARCHITECTURE.md 3 (loop ends on a structured Answer), ADR-004 "How" gains the server check, changelog fragment. Verify: `openspec validate --all --strict`, `mix precommit` and `mix credo` green.

## Workflow follow-up

- Archive with `openspec-archive-change structured-answers` in the build PR (#118).
