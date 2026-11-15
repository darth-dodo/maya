# Tasks: trainers-items-readiness

## 1. Data

- [ ] 1.1 Parsers for `trainers.h` (constant to party label), map `scripts.inc` (`trainerbattle_*`, `pokemart`), `map.json` item balls and hidden items, `item_ball_scripts.inc` and `items.h`, each with a fixture test. Verify: `mix test test/maya/game_data/parse_test.exs`.
- [ ] 1.2 Hand-write `priv/data/interiors.json` (marts and gyms Littleroot to Dewford, own `badges_required`) and `priv/data/gifts.json` (HMs and key items inside the horizon, each citing its pokeemerald script), then extend `mix maya.fetch_data`, run it once and commit `trainer_places.json`, `item_places.json` and `items.json`. Verify: `jq` shows Calvin1 on `MAP_ROUTE102` and no unlisted map.
- [ ] 1.3 Migration and import for `trainer_places`, `item_places`, `items` and gifts; the "never inherited" and "every map exists" checks. Verify: import tests and idempotency.

## 2. Tools

- [ ] 2.1 `find_trainer`: GameData query, Facts, definition, `Tools.call`. Verify: Route 102, Route 110 and Dewford Town tests.
- [ ] 2.2 `find_item`: GameData query (places plus gifts by badges), Facts, definition, `Tools.call`. Verify: ball fixture, HM03, Master Sword tests.
- [ ] 2.3 `team_check`: reuse the `gym_counter` ace and matchup code, add level gap and `ready`. Verify: Mudkip 5, Mudkip 13, empty Team and 8 badges tests.

## 3. Prompt, probes, latency, docs

- [ ] 3.1 Prompt lines for the three tools. Verify: prompt test.
- [ ] 3.2 Add the five cases to `test/fixtures/spoiler_probes.json`. Verify: `mix test --only spoiler_gate`.
- [ ] 3.3 Agent-stage p50 and p95 before and after in the PR. Verify: numbers in the PR body.
- [ ] 3.4 ARCHITECTURE.md 3 and 4 match, changelog fragment. Verify: `openspec validate --all --strict`, `mix precommit` and `mix credo` green.

## Workflow follow-up

- Archive with `openspec-archive-change trainers-items-readiness` in the build PR.
