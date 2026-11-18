# Tasks: guide-and-humor

Two build PRs. Part A (sections 1 and 2, 2h) says "Part of #41". Part B (section 3, 1h) says "Closes #41" and archives the change. Section 4 runs in each part for its own tool.

## 1. Locations and Walkthrough notes (part A)

- [x] 1.1 Add the seven rows to `priv/data/locations.json` (Granite Cave on `MAP_GRANITE_CAVE_1F`, Route 109 and Slateport City at 1; Route 107, Route 108, Route 110, Mauville City at 2), each map checked against `encounters.json` or the pinned pokeemerald map list; move the Horizon unlisted test from Route 110 to Route 111. Verify: `jq length priv/data/locations.json` prints 21; locations and Horizon tests green, including the badge 1 and badge 2 scenarios.
- [x] 1.2 Write `priv/data/walkthrough_notes.json`: 21 short original notes, Littleroot Town to Mauville City, from Maya's data files only (encounters, trainers, locations), each with its location's `badges_required`, inclusive language, never copied from a guide site. Verify: `jq length` prints 21.
- [x] 1.3 Note checker: no note names a listed location with a higher `badges_required` or a forbidden name. Verify: a test runs it on the committed file (green) and on the Route 116 and Mauville City fixtures (red).
- [x] 1.4 Migration for `walkthrough_notes`, `GameData.import!/1` loads it and fails on a note for an unlisted location or a lower `badges_required`. Verify: import tests, including the Verdanturf Town fixture and idempotency.

## 2. search_guide (part A)

- [x] 2.1 `GameData.walkthrough_note/2` (name, badges earned) filtering on `badges_required` in SQL; `Facts.search_guide/3` mapping to Fact, `past_horizon` or `not_found`. Verify: tests for Littleroot by default, Rustboro, Dewford and Granite Cave at 0 and 1 badges, Slateport City at 0 and 1, Route 110 and Mauville at 1 and 2 badges, Verdanturf and Narnia.
- [x] 2.2 Tool definition (`location` optional) and `Tools.call("search_guide", ...)`. Verify: `mix test test/maya/agent/tools_test.exs`.

## 3. set_setting (part B)

- [x] 3.1 `GameData.put_humor!/2` for one Guest. Verify: two-guest test.
- [x] 3.2 Tool definition and `Tools.call("set_setting", ...)` returning `{:logged, ...}` or `{:refused, ...}`; the agent loop uses the new Progress for the rest of the turn. Verify: tests for 60, spoilers 100, humor 140, and an agent test whose second request's system prompt shows humor 60.

## 4. Prompt, probes, latency, docs (each part, for its tool)

- [x] 4.1 Prompt line for the part's tool; part B adds the Dial honesty rule. Verify: prompt test. Part A done (#41 part A PR); part B done (#41 part B PR).
- [x] 4.2 Part A adds the guide cases at 0, 1 and 2 badges to `test/fixtures/spoiler_probes.json`, each with forbidden names for its badge count; part B adds the Dial and honesty cases. Verify: `mix test --only spoiler_gate`; the honesty case uses the #118 check (skipped with #118 named if it has not merged). Part A done (#41 part A PR); part B done (#41 part B PR).
- [ ] 4.3 Agent-stage p50 and p95 before and after in each PR; part B also has "Maya, humor 60 percent" said on the phone and confirmed out loud. Verify: numbers and a screenshot in the PR.
- [x] 4.4 ARCHITECTURE.md 3 and 4 and PRODUCT.md say Walkthrough notes reach Mauville City, CLAUDE.md status line, changelog fragment per PR. Verify: `openspec validate --all --strict`, `mix precommit` and `mix credo` green. Part A done (#41 part A PR).

## Workflow follow-up

- Archive with `openspec-archive-change guide-and-humor` in part B's build PR (#41).
