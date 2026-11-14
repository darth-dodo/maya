# Design

## Context

ARCHITECTURE.md section 4 and "Functional programming": pure core, thin shell. Fetching is the only step with network; it runs by hand and its output is committed. Import reads files only.

## Decisions

- **Pinned source.** pokeemerald commit `731ad5bfd6e6f265508d0efcca0ba42f9dcf5881` (master on 2026-11-14), hard-coded in the fetch task. PokeAPI has no versions, so its output is reviewed in the PR diff when refreshed.
- **One key per thing.** pokeemerald constants become PokeAPI style names at fetch time (`SPECIES_NIDORAN_F` to `nidoran-f`, `MOVE_ROCK_TOMB` to `rock-tomb`), so every file and table uses the same keys. Maps keep the pokeemerald id (`MAP_ROUTE102`); `locations` maps a spoken name to that id.
- **Files in `priv/data/`.** `species.json` (name, types, evolutions), `type_matchups.json` (only non-neutral pairs), `encounters.json` (one row per map, method and species, rate summed over slots, min and max level), `trainers.json` (label, name, gym badge, party with species, level, moves), `locations.json` (hand-written, never touched by the fetch). Only `gWildMonHeaders` encounters are kept (Battle Pyramid and Pike are left out).
- **Species set.** Every species in the kept encounters or trainer parties, plus their evolutions up to national number 386. Types use PokeAPI `past_types` for the earliest generation at or after III; type matchups use `past_damage_relations` the same way, and the Fairy type is dropped.
- **Gym leaders.** The first party of each leader (`Roxanne1` to `Juan1`) is tagged with its badge number from the gym list in `Maya.Horizon`, the one place the gym order lives.
- **Import.** One transaction: delete game data tables, `insert_all` in chunks. Progress is one row (id 1) inserted with `on_conflict: :nothing`, so it is seeded once.
- **Schemaless.** Tables are read with schemaless queries in `Maya.GameData`; no Ecto schemas until a tool needs one.
- **Horizon.** `Maya.Horizon` takes plain maps: `allowed?(%{badges_required: n}, progress)`; `nil` or any other shape is `false`, so a missing location fails closed. All `badges_required` are 0 for Littleroot to Rustboro: the horizon includes the Next gym.

## Risks

- PokeAPI evolution data is current-generation; targets past national number 386 are dropped, and methods are kept as PokeAPI gives them.
- Parsing C with regular expressions depends on pokeemerald's formatting; the pinned commit makes that stable, and the parser test guards it.
