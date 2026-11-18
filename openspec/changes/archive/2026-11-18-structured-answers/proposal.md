# Proposal: structured-answers

## Why

On the phone, 2026-11-15 20:28, Maya said she refused Ralts and Wooper because the Team was full, then admitted she never called `log_event`. ADR-004 says every Fact comes from a tool in this turn, but today nothing checks it: the loop returns whatever text the model writes. Abhishek chose option A on 2026-11-15: OpenRouter structured output (`response_format` with a JSON schema) validated by an Ecto embedded schema in the existing loop, no `instructor` dependency. Issue #118. Size: 2h on the board.

## What Changes

- **Structured Answer**: every agent request also carries `response_format: {type: "json_schema", json_schema: {name: "answer", strict: true, schema}}` and `provider: {require_parameters: true}`, so OpenRouter routes only to endpoints that support it. The final reply is `{"answer": string, "used_tool_calls": [tool_call_id]}`, parsed and validated by an Ecto embedded schema. Only `answer` is spoken, shown and stored.
- **Honesty check in the loop**: an Answer is rejected when it is not valid against the schema, when `used_tool_calls` names an id that is not a tool call of this turn, or when its text claims a write (an Event logged or refused, a Dial changed) and no `log_event` or `set_setting` result of this turn is in `used_tool_calls`. A rejected Answer gets one corrective request at most, inside the existing 4-request cap and 8 s agent budget; if that is rejected too, or no request or time is left, the Answer is the fallback line "Not sure I got that right, ask me again?".
- **Prompt**: a rule never to claim a tool call, its result or a refusal unless it happened in this turn, to list the ids used, and to say plainly when unsure.
- **Probes**: the existing honesty case (#40) runs through the loop and must end corrected or replaced, never spoken as is.
- **Latency**: agent-stage p50 and p95 before and after, and how often the corrective request fired.

Out of scope: streaming agent tokens into TTS (the agent stage already returns a whole reply today; noted in PHASE_2.md), the `instructor` library, the Response Healing plugin, a second corrective round, per-sentence Fact citations.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `agent`: the loop ends on a structured Answer instead of free text; honesty check, corrective request and fallback line; prompt rule; latency.

## Impact

- Code: `lib/maya/agent.ex` (request body, final reply handling), a new embedded schema `lib/maya/agent/answer.ex`, `lib/maya/agent/prompt.ex`. `Maya.Agent.answer/3` keeps returning `{:ok, text}`, so `Maya.Conversation`, `mix maya.compare_models` and the smoke controller do not change.
- Tests: `test/maya/agent_test.exs`, a new `test/maya/agent/answer_test.exs`, `test/maya/spoiler_gate_test.exs`; the claim words move from `test/fixtures/spoiler_probes.json` into the app.
- Voice loop: on the path to first sound. Agent-stage latency measured before and after; Answer time p95 stays at most 8 s.
- Model: `anthropic/claude-haiku-5.5` (ADR-007 default) lists `structured_outputs` and `tools`; some of its endpoints do not (see design), hence `require_parameters`.
- Issue: #118.
