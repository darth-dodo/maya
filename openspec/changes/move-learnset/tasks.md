# Tasks: move-learnset

## 1. Data

- [ ] 1.1 `Parse.learnset/2` reads a `pokemon` response and keeps `emerald` `level-up` rows (`species`, `move`, `method`, `level`), with a fixture test for the version group and machine cases. Verify: `mix test test/maya/game_data/parse_test.exs`.
- [ ] 1.2 `mix maya.fetch_data` writes `priv/data/learnsets.json` from the `pokemon` response it already fetches; run it once and commit the file. Verify: `jq 'map(select(.species=="mudkip")) | length'` is above 0 and Mudkip's rows match the spec scenario (if PokeAPI differs, the data wins and the scenario is corrected in this PR).
- [ ] 1.3 Migration for `learnsets` (index on `species`), `GameData.import!/1` loads it, `GameData.learnset/1` returns rows in level order. Verify: the import idempotency test and a Mudkip query test.

## 2. Horizon and tool

- [ ] 2.1 `Horizon.level_cap/2` (Progress, ace level) with the three spoiler-horizon scenarios. Verify: `mix test test/maya/horizon_test.exs`.
- [ ] 2.2 `Facts.move_learnset/4` using the shared "species inside the horizon" rule from `find_pokemon` (add it here if #40 has not merged). Verify: Facts tests for Mudkip, Groudon, Agumon and 8 badges.
- [ ] 2.3 Tool definition and `Tools.call("move_learnset", ...)` with `bad_arguments`. Verify: `mix test test/maya/agent/tools_test.exs`.
- [ ] 2.4 Prompt line for `move_learnset`. Verify: prompt test asserts the line and no "beat" or "defeat".

## 3. Probes, latency, docs

- [ ] 3.1 Add the three move cases to `test/fixtures/spoiler_probes.json` with Mudkip's moves above 15 in the forbidden list. Verify: `mix test --only spoiler_gate`.
- [ ] 3.2 Agent-stage p50 and p95 from `mix maya.latency` before and after, in the PR. Verify: numbers in the PR body.
- [ ] 3.3 ARCHITECTURE.md 3 tool table and 4 data table, changelog fragment. Verify: `openspec validate --all --strict`, `mix precommit` and `mix credo` green.

## Workflow follow-up

- Archive with `openspec-archive-change move-learnset` in the build PR.
