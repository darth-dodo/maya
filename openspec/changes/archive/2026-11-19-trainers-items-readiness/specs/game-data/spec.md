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

### Requirement: Hand-listed interiors up to Mauville City
`interiors.json` SHALL list each interior's map, its city (a listed location) and its own `badges_required`, covering the marts in Oldale Town, Petalburg City, Rustboro City, Slateport City and Mauville City and the gyms in Rustboro City, Dewford Town and Mauville City. The import SHALL fail when an interior's or a gift's `badges_required` is below its city's.

#### Scenario: Interior below its city
- **WHEN** the import reads an interiors fixture with the Mauville City mart at 1 badge
- **THEN** the import fails and no table is changed

#### Scenario: Every hand-listed map exists
- **WHEN** the committed `gifts.json` and `interiors.json` are checked
- **THEN** every map in them was fetched without error

### Requirement: Places reachable only with an HM
The hand-written `access.json` SHALL list each ball, hidden item and trainer on a listed map that the player can reach only with an HM or from a later map, with a `badges_required` that is the later of its map's and the badge that lets the HM be used (Cut 1, Surf 5). The import SHALL give that row this value, and SHALL fail on an access row that matches no fetched place.

#### Scenario: Items behind Surf
- **WHEN** Progress has badges 1 and 2 and `find_item` is called for "Star Piece" (a ball on a Route 108 island)
- **THEN** it returns `past_horizon`
- **AND** with badge 1, "Iron" names Slateport City and not Route 105

#### Scenario: East Route 103 waits for Route 110
- **WHEN** Progress has 0 badges and `find_trainer` is called for "Route 103"
- **THEN** no trainer from the east side (reached from Route 110) is listed
- **AND** with badges 1 and 2 they are listed, except the two reached only by Surf
