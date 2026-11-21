# Tasks: longer-memory

One build PR, size S. It says "Closes #N" and archives the change. If it passes 2x, cut the cached token count from the log line first (keep rounds and history).

## 0. Baseline

- [ ] 0.1 Before any change: agent-stage p50 and p95 from `mix maya.latency` (or Abhishek's phone run of 10 Questions in one Conversation). Verify: numbers saved for the PR body.

## 1. Window

- [ ] 1.1 One window of 25 turns for `Agent.messages/3`, the Conversation's in-memory turns and its reload (`Turn.recent/2`). Verify: 30 stored turns give 25 in the request; restart reload test.

## 2. Caching and log line

- [ ] 2.1 Top-level `cache_control` `{"type": "ephemeral"}` in the request body for `anthropic/` models only. Verify: stubbed request body tests for Haiku and Gemini; 2 round prefix test.
- [ ] 2.2 Sum `usage.prompt_tokens` and `usage.prompt_tokens_details.cached_tokens` across rounds; one info line per answered Question with rounds, history turns, prompt and cached tokens. Verify: `capture_log` test that the line has the numbers and no Question or Answer text.

## 3. Live proof, latency, docs

- [ ] 3.1 One live turn (Render log or local with `OPENROUTER_API_KEY`) shows cached tokens above 0 on round 2 or the next turn. Verify: log line pasted in the PR.
- [ ] 3.2 Agent-stage p50 and p95 after, next to 0.1, in the PR body; Answer time p95 at most 8 s. Verify: numbers in the PR.
- [ ] 3.3 PRODUCT.md "Answers" (25 turns), ARCHITECTURE.md 3 and the Conversation section, changelog fragment. Verify: `openspec validate --all --strict`, `mix precommit` and `mix credo` green.
