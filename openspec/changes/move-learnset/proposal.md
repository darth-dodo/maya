# Proposal: move-learnset

## Why

Maya already says move Facts out loud ("Mudkip learns Water Gun soon") with no tool behind them. That breaks ADR-004 (Facts only from tools) and can leak moves learned far past the Next gym. Abhishek ranked this first on 2026-11-15 ("Yes"). Size: M (1h on the board).

## What Changes

- **Data**: `mix maya.fetch_data` also writes `priv/data/learnsets.json`: for each species it already fetches, the level-up moves from the PokeAPI `emerald` version group (`move`, `level`, `method`). It reuses the `pokemon` response the fetch already downloads for types, so no new endpoint. Fetched once and committed.
- **Import**: a new `learnsets` table (`species`, `move`, `method`, `level`), loaded by `mix maya.import` in the same transaction as the other game tables.
- **Level horizon**: the highest level reachable before the Next gym is the level of the Next gym leader's ace (Roxanne's Nosepass, 15, at 0 badges), or the Team's highest level when that is higher. With all 8 badges there is no cap.
- **Tool**: `move_learnset(species)` returns `{:ok, fact}` with the species and its level-up moves at or below the level horizon, `{:error, :not_found}` for an unknown species, and `{:error, :past_horizon}` for a species the Guest cannot meet inside the horizon (the same rule `find_pokemon` uses after `sunday-goal`: a wild place inside the horizon, or on the Team).
- **Prompt**: one line telling Maya to call `move_learnset` before naming any move a Pokémon learns, and never to name a move it did not return.
- **Probe cases**: three cases for the spoiler probe set (#40).

Out of scope: TM and HM moves (the `method` column is ready for them; a later change), move types, power and accuracy, egg and tutor moves, Team members' current movesets. New ideas go to PHASE_2.md.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `agent`: new tool `move_learnset`, its prompt line and its probe cases.
- `game-data`: learnsets fetched from PokeAPI (Emerald) and imported.
- `spoiler-horizon`: the level horizon (Next gym ace level).

## Impact

- Code: `lib/mix/tasks/maya.fetch_data.ex`, `lib/maya/game_data/parse.ex`, `lib/maya/game_data.ex`, `lib/maya/horizon.ex`, `lib/maya/agent/facts.ex`, `lib/maya/agent/tools.ex`, `lib/maya/agent/prompt.ex`, a migration, `priv/data/learnsets.json`.
- Tests: parse fixture, import, Facts, Tools, prompt, probe cases in `test/fixtures/spoiler_probes.json`.
- Voice loop: one more tool definition per agent request; agent-stage latency measured before and after.
- Depends on `sunday-goal` (#40) for the probe file and the shared "inside the horizon" species rule; if #40 has not merged, this change adds the rule itself.
- Issue: see the spec PR.
