# Tasks: trainers-items-readiness

Two build PRs, after `guide-and-humor` part A has merged (locations through Mauville City). Part A (sections 1 and 2, 2h) says "Part of #121". Part B (section 3, 45m) says "Closes #121" and archives the change. Section 4 runs in each part for its own tools.

## 1. Data (part A)

- [x] 1.1 Parsers for `trainers.h` (constant to party label), map `scripts.inc` (`trainerbattle_*`, `pokemart`), `map.json` item balls and hidden items, `item_ball_scripts.inc` and `items.h`, each with a fixture test. Verify: `mix test test/maya/game_data/parse_test.exs`.
- [x] 1.2 Hand-write `priv/data/interiors.json` (marts in Oldale, Petalburg, Rustboro, Slateport and Mauville; gyms in Rustboro, Dewford and Mauville; each with its city and own `badges_required`) and `priv/data/gifts.json` (HMs and key items Littleroot Town to Mauville City, each citing its pokeemerald script; drop any not found), then extend `mix maya.fetch_data`, run it once and commit `trainer_places.json`, `item_places.json` and `items.json`. Verify: `jq` shows Calvin1 on `MAP_ROUTE102`, trainers on `MAP_ROUTE110`, and no unlisted map.
- [x] 1.3 Migration and import for `trainer_places`, `item_places`, `items` and gifts; the "never inherited", "not below its city" and "every map exists" checks. Verify: import tests, the Mauville mart at 1 badge fixture, and idempotency.

## 2. Tools (part A)

- [x] 2.1 `find_trainer`: GameData query, Facts, definition, `Tools.call`. Verify: Route 102 at 0, Route 110 at 0, 1 and 2 badges, Dewford Town at 0 tests.
- [x] 2.2 `find_item`: GameData query (places plus gifts by badges), Facts, definition, `Tools.call`. Verify: ball fixture, HM03 at 0 and 2, Mach Bike at 1 and 2, Master Sword tests.

## 3. team_check (part B)

- [x] 3.1 `team_check`: reuse the `gym_counter` ace and matchup code, add level gap and `ready`. Verify: Mudkip 5, Mudkip 13, empty Team, Wattson at 2 badges and 8 badges tests.
- [x] 3.2 Part A review F5: one rival entry with the party for the player's starter, or one line when it is unknown. Verify: Route 103 Facts and Tools tests.
- [x] 3.3 Part A review F6: `access.json` from a walk over each map's layout raises balls, hidden items and trainers behind Cut, Surf or a later route. Verify: Star Piece, Iron, X Accuracy and east Route 103 tests, and the unknown access row check.

## 4. Prompt, probes, latency, docs (each part, for its tools)

- [x] 4.1 Prompt lines for the part's tools. Verify: prompt test.
- [x] 4.2 Add the part's cases at 0, 1 and 2 badges to `test/fixtures/spoiler_probes.json`, each with forbidden names for its badge count. Verify: `mix test --only spoiler_gate`.
- [ ] 4.3 Agent-stage p50 and p95 before and after in each PR. Verify: numbers in the PR body.
- [x] 4.4 ARCHITECTURE.md 3 and 4 match, changelog fragment per PR. Verify: `openspec validate --all --strict`, `mix precommit` and `mix credo` green.

## Workflow follow-up

- Archive with `openspec-archive-change trainers-items-readiness` in part B's build PR (#121).
