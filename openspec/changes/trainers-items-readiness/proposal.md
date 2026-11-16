# Proposal: trainers-items-readiness

## Why

Three common Questions still have no tool, so Maya says "Not sure" or answers from memory (ADR-004): "Who battles me on Route 102?", "Where do I get a Potion?" and "Is my Team ready for Roxanne?". Abhishek ranked this third on 2026-11-15 ("Yes"), as one later block, and widened places and gifts to gym 3 (Mauville City) on 2026-11-16 ("Do till gym 3"). Size: 2h45 in two build PRs (part A 2h, part B 45m), since one PR would pass the 2h block limit. If part A passes 2x, cut gifts from `find_item` first.

## What Changes

Part A (trainers and items, 2h):

- **Data**: `mix maya.fetch_data` also reads, at the pinned pokeemerald commit, `src/data/trainers.h` (trainer constant to party label), `include/constants/items.h` (every item name), `data/scripts/item_ball_scripts.inc`, and `scripts.inc` plus `map.json` for each listed location's map (Littleroot Town to Mauville City, from `guide-and-humor` part A) and each map in a new hand-written `priv/data/interiors.json`. `interiors.json` lists the marts in Oldale Town, Petalburg City, Rustboro City, Slateport City and Mauville City and the gyms in Rustboro City, Dewford Town and Mauville City, each with its own `badges_required` (Rustboro Gym 0, Dewford Gym 1, Slateport and Mauville marts and Mauville Gym 2). It writes `priv/data/trainer_places.json` (map, party label) and `priv/data/item_places.json` (item, map, how: `ball`, `hidden` or `mart`). A hand-written `priv/data/gifts.json` lists HMs and key items given from Littleroot Town to Mauville City (for example HM01 Cut in Rustboro City, HM05 Flash in Granite Cave, HM06 Rock Smash and the Mach and Acro Bikes in Mauville City) with their map, `badges_required` and how they are given, each confirmed in its pokeemerald script.
- **Import**: tables `trainer_places`, `item_places` and `items`, loaded by `mix maya.import`.
- **Tool `find_trainer(place)`**: the trainers on a place with their first party (species and levels), never a rematch party. `{:ok, fact}`, or `{:error, :past_horizon}` for a place past the horizon or not listed (fail closed, as `search_guide`).
- **Tool `find_item(name)`**: where to get an item inside the horizon (place and how). `{:ok, fact}`; `{:error, :past_horizon}` for a known item with no place inside the horizon (HM03 Surf at 2 badges, the Mach Bike at 1); `{:error, :not_found}` for a name not in `items.h`.
- **Prompt and probes**: lines and probe cases for `find_trainer` and `find_item`, at 0, 1 and 2 badges.

Part B (readiness, 45m):

- **Tool `team_check()`**: the Guest's Team against the Next gym's ace: each member's level gap and best type multiplier, and a `ready` verdict. Only the Next gym, never a later one: Roxanne, Brawly or Wattson inside this scope.
- **Prompt and probes**: the `team_check` line and its probe cases.

Out of scope: places past Mauville City, berries, Pokémon gifts (eggs, Wally's battle), TM moves, rematches, Trainer Hill and the Battle Frontier (PHASE_2.md).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `agent`: new tools `find_trainer`, `find_item`, `team_check`, prompt lines, probe cases.
- `game-data`: trainer places, item places, gifts, interiors and the item list.

## Impact

- Code: `lib/mix/tasks/maya.fetch_data.ex`, `lib/maya/game_data/parse.ex`, `lib/maya/game_data.ex`, `lib/maya/agent/facts.ex`, `lib/maya/agent/tools.ex`, `lib/maya/agent/prompt.ex`, a migration, new `priv/data/` files.
- Voice loop: three more tool definitions per request; agent-stage latency measured before and after in each part.
- Depends on `guide-and-humor` part A (#41) for the locations through Mauville City, on `move-learnset` for the level horizon used by `team_check`, and on `sunday-goal` (#40) for the probe file.
- Issue: #121. Part A's PR says "Part of #121"; part B's PR says "Closes #121" and archives the change.
