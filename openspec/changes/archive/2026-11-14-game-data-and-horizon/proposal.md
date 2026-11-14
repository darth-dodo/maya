# Proposal

GitHub Issue: #37

## Why

Maya's tools may only speak Facts from Maya's own data (ADR-004), and the Spoiler horizon can only be enforced on data Maya controls. Block 1 gives the later agent tools that data: Hoenn game data in Postgres, the player's Progress, and a pure Spoiler horizon that fails closed.

## What Changes

- `mix maya.fetch_data` downloads pret/pokeemerald `src/data/wild_encounters.json` and `src/data/trainer_parties.h` from one pinned commit, plus the species and type data Maya needs from PokeAPI as of Generation III, and writes compact JSON into `priv/data/`. The output is committed; it is run again only to refresh the data.
- `mix maya.import` (and `Maya.Release.import_data/0` for the release) loads Postgres only from `priv/data/` and `priv/progress.json`, with no network. Game data is replaced in one transaction, so a second run gives the same rows. Progress is seeded only when the table is empty (ADR-006).
- New tables: `species`, `type_matchups`, `encounters`, `trainers`, `trainer_pokemon`, `locations` (hand-written, Littleroot Town to Rustboro City), `progress`.
- A pure Spoiler horizon: the Next gym, the badges earned, and whether a location is allowed. A location not in the table is never allowed.
- Out of scope: agent tools, moves table, Walkthrough notes, embeddings, locations past Rustboro City, the `turns` table (Issue #38). New ideas go to PHASE_2.md.

## Capabilities

### New Capabilities
- `game-data`: fetching game data into committed files and importing it into Postgres, including Progress.
- `spoiler-horizon`: the Next gym, badges earned and the allowed-location rule.

### Modified Capabilities
None.

## Impact

- New: `lib/maya/game_data.ex` and `lib/maya/game_data/*`, `lib/maya/horizon.ex`, `lib/mix/tasks/maya.fetch_data.ex`, `lib/mix/tasks/maya.import.ex`, one migration, `priv/data/*.json`, `priv/progress.json`, tests and fixtures.
- Changed: `lib/maya/release.ex` (`import_data/0`).
- No new dependencies (Req, Jason and Ecto are already in `mix.exs`).
