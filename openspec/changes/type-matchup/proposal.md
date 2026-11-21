# Proposal: type-matchup

## Why

PRODUCT.md promises "What's Geodude weak to?", but no tool answers a type question on its own: `find_pokemon` gives types without multipliers, and `gym_counter` and `team_check` rate only the Team against a gym's ace. So Maya says "Not sure" or reaches for memory (ADR-004). Abhishek chose option B on 2026-11-21: a read tool for type matchups plus a short reason line per notable pair, so an Answer says the multiplier first and a bit of flavour after it.

## What Changes

- **Data**: a hand-written `priv/data/type_reasons.json`: one short, original reason line per notable pair (for example "Water puts out Fire", "Electric cannot reach Ground"), each with `attacker`, `defender`, `multiplier` and `reason`. Loaded into a `type_reasons` table by `mix maya.import`.
- **Import check** (fail closed, like the Walkthrough notes): every reason's pair is in `type_matchups.json` with the same multiplier; no Fairy; no pair twice; one line of at most 60 characters; never "beat" or "defeat".
- **Tool `type_matchup(attacker?, defender)`**: `defender` is a type, a Pokémon or a gym leader (meaning that leader's ace). With `attacker`, the multiplier on the defender's one or two types. Without it, the types that hit 2x or more and the types to avoid (half and zero). Each pair carries its reason line when one exists. Multipliers come only from `type_matchups.json` (Generation III, 17 types). A Pokémon or a leader past the Spoiler horizon is `past_horizon`.
- **Prompt**: one line: call `type_matchup` for what is good against, weak to or why; say the multiplier first, the reason as flavour, nothing it did not return.
- **Honesty and probes**: `type_matchup` is a read, so it backs no write claim. Probe cases at 0 and 2 badges.
- **Latency**: request size and agent-stage p50 and p95 before and after.

Size: M (one build PR).

Out of scope: abilities (Levitate, Wonder Guard), move types and STAB, weather, Fairy, held items and a type for a move by name. New ideas go to PHASE_2.md.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `agent`: tool `type_matchup`, its prompt line, honesty, probe cases and latency.
- `game-data`: `type_reasons.json` and its import check.

## Impact

- Code: `lib/maya/agent/facts.ex`, `lib/maya/agent/tools.ex`, `lib/maya/agent/prompt.ex`, `lib/maya/game_data.ex`, a new pure checker next to `lib/maya/game_data/notes.ex`, a migration, `priv/data/type_reasons.json`, `test/fixtures/spoiler_probes.json`.
- Voice loop: one more tool definition on every agent request (request size and agent latency measured before and after).
- Issue: to be filed after this spec PR (factory:plan step 6).
