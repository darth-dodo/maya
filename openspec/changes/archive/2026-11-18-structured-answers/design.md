# Design: structured-answers

## Context

`Maya.Agent.loop/5` posts to `/v1/chat/completions` with `model`, `messages` and `tools`, without streaming. It returns the first non-empty `content` as the Answer; `Maya.Conversation` then hands that whole string to `TTS.stream/2`. So the agent stage already ends only when the full reply has arrived, and TTS streams from there. The honesty check today lives only in a test (`claim_words` in `test/fixtures/spoiler_probes.json`); the app never checks a reply.

OpenRouter (https://openrouter.ai/docs/guides/features/structured-outputs, read 2026-11-16):

- Chat Completions takes `response_format: {type: "json_schema", json_schema: {name, strict, schema}}`.
- Support is per endpoint, not per model. Set `provider.require_parameters: true` to route only to endpoints that support every parameter sent (https://openrouter.ai/docs/guides/routing/provider-selection).
- Structured outputs work with `stream: true`. Some providers enforce the schema, others treat it as a strong hint.
- The page does not say whether `response_format` combines with `tools` in one request; the tool calling guide (https://openrouter.ai/docs/guides/features/tool-calling) does not either.

`GET https://openrouter.ai/api/v1/models` on 2026-11-16: `anthropic/claude-haiku-5.5` (the configured `agent_model`), `google/gemini-3.8-flash` and `openai/gpt-5.4-mini` all list `structured_outputs`, `response_format` and `tools`. Per endpoint (`/api/v1/models/anthropic/claude-haiku-5.5/endpoints`): Anthropic, Google and Azure support `structured_outputs`; Amazon Bedrock and Claude Platform on AWS do not. Without `require_parameters` a request could land on Bedrock and the schema would be ignored.

## Goals / Non-Goals

**Goals:** Maya never speaks a claim about a tool that did not run this turn; every Answer carries which tool calls it used; no new dependency; Answer time p95 stays at most 8 s.

**Non-Goals:** streaming agent tokens (PHASE_2.md); checking each Fact sentence against tool content; changing the model (ADR-007 stays).

## Decisions

- **Schema in every request, tools too.** We cannot know which request is the last, so every request carries both `tools` and `response_format`. A tool round still comes back as `tool_calls`; the final reply comes back as schema JSON in `content`. Task 1.1 checks this on the configured model before anything else is built. If the configured model will not do both in one request, stop and ask Abhishek: the fallback inside the stack is a forced `answer` tool (`tool_choice: "required"`, the Answer as its arguments), which is not option A.
- **Schema:** `{"type": "object", "properties": {"answer": {"type": "string"}, "used_tool_calls": {"type": "array", "items": {"type": "string"}}}, "required": ["answer", "used_tool_calls"], "additionalProperties": false}`, `strict: true`. `answer` comes first so a later streaming change can start TTS once that string closes.
- **Ecto embedded schema `Maya.Agent.Answer`** (`embedded_schema` with `answer` and `used_tool_calls`, a changeset with `validate_required` and `validate_length(:answer, min: 1)`). It runs whatever the provider promised, since some providers treat the schema as a hint. Ecto is already a dependency; no `instructor`.
- **Honesty rules, server side.** (1) Every id in `used_tool_calls` is a tool call id of this turn. (2) If `answer` contains a claim word (the list moves from the probe fixture into `Maya.Agent.Answer`), some id in `used_tool_calls` is a `log_event` or `set_setting` call of this turn. An Answer that uses no tool and claims nothing passes, so "Not sure" and chat still work.
- **Reject, then one corrective request, then the fallback.** The corrective request appends the rejected reply as an assistant message and a user message naming the reason ("You cited call_9, which did not run" or "You said you refused something, but no log_event ran"). It is one of the 4 requests and runs on the same deadline. A second rejection, or no request or time left, gives "Not sure I got that right, ask me again?". The only repair is that fallback; Maya never rewrites the model's text.
- **The contract with the caller stays `{:ok, text}`.** The Conversation, `mix maya.compare_models` and the smoke controller see the `answer` string only, so history turns stay plain text.
- **Streaming and the voice loop.** Nothing on the path to first sound changes shape: the agent stage still ends with a whole reply, then TTS streams `answer` as today. The cost is a few JSON tokens per reply and, only when a reply is rejected, one more request. `answer` comes first in the schema and OpenRouter supports structured output with `stream: true`, so the PHASE_2.md streaming idea stays open.

## Risks / Trade-offs

- [`require_parameters` narrows routing to fewer endpoints] → agent-stage p50 and p95 are measured before and after; if p95 rises past 3 s (ADR-007's check), re-run `mix maya.compare_models` with the schema on.
- [The claim word list misses a phrasing, or flags a harmless one] → the list is one module attribute with a test per word; a false flag costs one corrective request, not a wrong Answer.
- [A corrective request pushes a slow Question past 8 s] → it runs on the same deadline; when time is short the fallback line is spoken instead.
- [The model lists ids it did not use] → harmless for honesty; only ids that did not run are rejected.
