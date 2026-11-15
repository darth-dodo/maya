# Proposal: trainers-items-readiness

## Why

Three common Questions still have no tool, so Maya says "Not sure" or answers from memory (ADR-004): "Who battles me on Route 102?", "Where do I get a Potion?" and "Is my Team ready for Roxanne?". Abhishek ranked this third on 2026-11-15 ("Yes"), as one later block. Size: L (2h on the board); if the build passes 2x, cut gifts from `find_item` first.

## What Changes

- **Data**: `mix maya.fetch_data` also reads, at the pinned pokeemerald commit, `src/data/trainers.h` (trainer constant to party label), `include/constants/items.h` (every item name), `data/scripts/item_ball_scripts.inc`, and `scripts.inc` plus `map.json` for each listed location's map and each map in a new hand-written `priv/data/interiors.json` (marts and gyms inside the horizon, each with its own `badges_required`). It writes `priv/data/trainer_places.json` (map, party label) and `priv/data/item_places.json` (item, map, how: `ball`, `hidden` or `mart`). A hand-written `priv/data/gifts.json` lists gifts (HMs, key items) with their map, `badges_required` and how they are given.
- **Import**: tables `trainer_places`, `item_places` and `items`, loaded by `mix maya.import`.
- **Tool `find_trainer(place)`**: the trainers on a place with their first party (species and levels), never a rematch party. `{:ok, fact}`, or `{:error, :past_horizon}` for a place past the horizon or not listed (fail closed, as `search_guide`).
- **Tool `find_item(name)`**: where to get an item inside the horizon (place and how). `{:ok, fact}`; `{:error, :past_horizon}` for a known item with no place inside the horizon (HM03 Surf at 0 badges); `{:error, :not_found}` for a name not in `items.h`.
- **Tool `team_check()`**: the Guest's Team against the Next gym's ace: each member's level gap and best type multiplier, and a `ready` verdict. Only the Next gym, never a later one.
- **Prompt**: one line per tool.
- **Probe cases**: trainer, item and readiness cases for the spoiler probe set (#40).

Out of scope: berries, Pokémon gifts (eggs, Wally's battle), TM moves, rematches, Trainer Hill and the Battle Frontier (PHASE_2.md).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `agent`: new tools `find_trainer`, `find_item`, `team_check`, prompt lines, probe cases.
- `game-data`: trainer places, item places, gifts, interiors and the item list.

## Impact

- Code: `lib/mix/tasks/maya.fetch_data.ex`, `lib/maya/game_data/parse.ex`, `lib/maya/game_data.ex`, `lib/maya/agent/facts.ex`, `lib/maya/agent/tools.ex`, `lib/maya/agent/prompt.ex`, a migration, new `priv/data/` files.
- Voice loop: three more tool definitions per request; agent-stage latency measured before and after.
- Depends on `move-learnset` for the level horizon used by `team_check`, and on `sunday-goal` (#40) for the probe file.
- Issue: see the spec PR.
