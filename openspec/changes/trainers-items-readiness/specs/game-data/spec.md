## ADDED Requirements

### Requirement: Trainer and item places from pinned sources
The fetch task SHALL read, at the pinned pokeemerald commit, only the maps of listed locations and of the hand-written `interiors.json`, and SHALL write `trainer_places.json` (map, party label), `item_places.json` (item, map, how: `ball`, `hidden` or `mart`) and `items.json` (every item name) to `priv/data/`. The import SHALL load these and the hand-written `gifts.json` (item, map, `badges_required`, how) in the same transaction as the other game tables.

#### Scenario: Trainer place parsed from a map script
- **WHEN** the parser reads a Route 102 `scripts.inc` fixture with `trainerbattle_single TRAINER_CALVIN_1` and a `trainers.h` fixture mapping it to `sParty_Calvin1`
- **THEN** it returns one row: map `MAP_ROUTE102`, party label `Calvin1`

#### Scenario: Item ball parsed
- **WHEN** the parser reads a `map.json` fixture whose object event script runs `finditem ITEM_POTION`
- **THEN** it returns one row: item `potion`, that map, how `ball`

#### Scenario: Interior maps are never inherited
- **WHEN** the committed data is imported
- **THEN** no row in `trainer_places` or `item_places` has a map that is neither a listed location nor in `interiors.json`
- **AND** `interiors.json` has no Petalburg City gym row with fewer than 5 badges required

#### Scenario: Every hand-listed map exists
- **WHEN** the committed `gifts.json` and `interiors.json` are checked
- **THEN** every map in them was fetched without error
