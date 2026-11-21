# Design: longer-memory

## Context

See proposal.md, Why. Today `Maya.Agent.messages/3` takes the last `@history 5` turns; the Conversation process holds at most 20 turns (`Enum.take(..., -20)` in `conversation.ex`) and reloads 20 (`Turn.recent/2` default). Every request is built as system prompt, history, Question, with `tools`, `response_format` and `provider.require_parameters` in the body. The system prompt carries Progress and humor, and is rebuilt after a write in the same turn.

## Goals / Non-Goals

- Goal: 25 turns of context with caching that pays off inside a turn (rounds 2 to 4) and across turns.
- Non-goal: summarising or recalling turns older than 25 (journal, embeddings: later changes).

## Decisions

1. **One window constant shared by agent and Conversation.** 25 turns sent; the Conversation keeps and reloads at least 25. The Talk screen then shows up to 25 turns instead of 20, which keeps one number. Alternative: separate screen and agent windows, rejected as extra state.
2. **Top-level `cache_control` over explicit breakpoints.** OpenRouter's docs describe a single top-level `"cache_control": {"type": "ephemeral"}` for Anthropic (also Vertex, Bedrock, Azure): OpenRouter puts the breakpoint on the last cacheable block and moves it forward as the conversation grows. Explicit breakpoints (up to 4, on content parts) would mean turning message strings into content arrays for little gain. Source: https://openrouter.ai/docs/guides/best-practices/prompt-caching.
3. **Only for `anthropic/` models.** The same docs list OpenAI, Gemini 2.5 and newer, DeepSeek and others as caching automatically; sending the field only where it is needed keeps `mix maya.compare_models` safe for other models.
4. **Tokens from `usage`.** OpenRouter reports `usage.prompt_tokens` and `usage.prompt_tokens_details.cached_tokens` (and `cache_write_tokens`). The loop sums them across rounds for the turn log line; missing fields count as 0.
5. **5 minute TTL.** The default. Maya turns are minutes apart while playing; 1 hour writes cost 2x and wait for evidence.

## Risks / Trade-offs

- [Progress in the system prompt changes after an Event, so history after it is not a cache hit on the next turn] → Accepted for now; the turn log line shows the hit rate. Moving Progress after the history is a later change if cached tokens stay low.
- [Haiku 5.5 caches only prompts of 512 tokens or more (OpenRouter docs)] → The system prompt plus tool definitions are well above that; the live log line proves it.
- [`provider.require_parameters` might route differently with `cache_control`] → The build's live turn checks the request still answers and reports cached tokens.
- [More history tokens slow the agent stage] → p50 and p95 before and after are in the Done when; cut back to fewer turns if p95 passes 8 s.
- [Cache writes cost 1.25x] → Reads at 0.1x on rounds 2 to 4 and the next turn should outweigh them; cost is not a gate.

## Migration Plan

No data change. Rollback: set the window back to 5 and drop the field.

## Open Questions

- Whether OpenRouter ignores or rejects top-level `cache_control` on non-Anthropic endpoints; Decision 3 avoids depending on it.
