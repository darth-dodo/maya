# Tasks: guide-and-humor

## 1. Walkthrough notes

- [ ] 1.1 Write `priv/data/walkthrough_notes.json`: 14 short original notes, Littleroot Town to Dewford Town, from Maya's data files only (encounters, trainers, locations), each with its location's `badges_required`, inclusive language. Verify: `jq length` prints 14.
- [ ] 1.2 Note checker: no note names a listed location with a higher `badges_required` or a forbidden name. Verify: a test runs it on the committed file (green) and on the Route 116 fixture (red).
- [ ] 1.3 Migration for `walkthrough_notes`, `GameData.import!/1` loads it and fails on a note for an unlisted location or a lower `badges_required`. Verify: import tests, including the Mauville fixture and idempotency.

## 2. search_guide

- [ ] 2.1 `GameData.walkthrough_note/2` (name, badges earned) filtering on `badges_required` in SQL; `Facts.search_guide/3` mapping to Fact, `past_horizon` or `not_found`. Verify: tests for Littleroot by default, Rustboro, Dewford at 0 and 1 badges, Mauville and Narnia.
- [ ] 2.2 Tool definition (`location` optional) and `Tools.call("search_guide", ...)`. Verify: `mix test test/maya/agent/tools_test.exs`.

## 3. set_setting

- [ ] 3.1 `GameData.put_humor!/2` for one Guest. Verify: two-guest test.
- [ ] 3.2 Tool definition and `Tools.call("set_setting", ...)` returning `{:logged, ...}` or `{:refused, ...}`; the agent loop uses the new Progress for the rest of the turn. Verify: tests for 60, spoilers 100, humor 140, and an agent test whose second request's system prompt shows humor 60.

## 4. Prompt, probes, latency, docs

- [ ] 4.1 Prompt lines for `search_guide` and `set_setting` and the Dial honesty rule. Verify: prompt test.
- [ ] 4.2 Add the five guide and Dial cases to `test/fixtures/spoiler_probes.json`. Verify: `mix test --only spoiler_gate`; the honesty case uses the #118 check (skipped with #118 named if it has not merged).
- [ ] 4.3 Agent-stage p50 and p95 before and after in the PR; "Maya, humor 60 percent" said on the phone and confirmed out loud. Verify: numbers and a screenshot in the PR.
- [ ] 4.4 ARCHITECTURE.md 3 and 4 match, CLAUDE.md status line, changelog fragment. Verify: `openspec validate --all --strict`, `mix precommit` and `mix credo` green.

## Workflow follow-up

- Archive with `openspec-archive-change guide-and-humor` in the build PR (#41).
