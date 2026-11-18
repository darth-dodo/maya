# game-data Specification

## Purpose

Keeps Maya's game Facts (species, type matchups, wild encounters, trainers, locations) and the player's Progress in Postgres, loaded only from files committed in the repository.

## Requirements

### Requirement: Game data fetched from pinned sources
The fetch task SHALL download pokeemerald data from one pinned commit and PokeAPI data as of Generation III, and SHALL write compact JSON files to `priv/data/` that are committed. Species types SHALL be the Generation III types (no Fairy type).

#### Scenario: Trainer parties parsed from the C source
- **WHEN** the trainer parties parser reads a fixture with Roxanne's first party
- **THEN** it returns the trainer `Roxanne1` tagged with badge 1 and three Pokémon: Geodude level 12, Geodude level 12, Nosepass level 15, with their moves

#### Scenario: Encounter rates summed per species
- **WHEN** the encounter parser reads a fixture with Route 102 land slots
- **THEN** each species on Route 102 land has one row whose rate is the sum of its slot rates

#### Scenario: Generation III types
- **WHEN** the species parser reads a PokeAPI fixture whose `past_types` lists Generation V types
- **THEN** the species gets the Generation V types, not the current ones

#### Scenario: No network in tests
- **WHEN** the test suite runs
- **THEN** no test downloads data; fetch tests use fixtures

### Requirement: Import from committed files only
The import task SHALL load the game data tables only from `priv/data/` and SHALL replace them in one transaction, so running it twice gives the same rows.

#### Scenario: Import is idempotent
- **WHEN** the import runs twice on the committed files
- **THEN** every game data table has the same row count after the second run as after the first

#### Scenario: Roxanne's team is queryable
- **WHEN** the committed data is imported and Roxanne's team is queried
- **THEN** it is Geodude level 12, Geodude level 12 and Nosepass level 15, in that order

#### Scenario: Ralts' Route 102 rate is queryable
- **WHEN** the committed data is imported and Ralts' land encounters on Route 102 are queried
- **THEN** one row is returned with rate 4 percent at level 4

### Requirement: Hand-written locations
The `locations` table SHALL list, with badges required 0, Littleroot Town, Routes 101 to 104, Oldale Town, Petalburg City, Petalburg Woods and Rustboro City; with 1, Route 116, Rusturf Tunnel, Routes 105, 106 and 109, Dewford Town, Granite Cave and Slateport City; with 2, Routes 107, 108 and 110 and Mauville City. Granite Cave SHALL map to its first floor only. Every other location stays unlisted, so past the Spoiler horizon (fail closed). Every deploy reloads it from the committed file.

#### Scenario: Locations up to Rustboro City
- **WHEN** the committed data is imported
- **THEN** Littleroot Town to Rustboro City, nine locations, each have badges required 0

#### Scenario: Locations up to Mauville City
- **WHEN** the committed data is imported
- **THEN** exactly those twenty-one locations exist, each with a badges required value

#### Scenario: Through Dewford after badge 1
- **WHEN** Progress has badge 1
- **THEN** Route 104, Dewford Town, Granite Cave and Slateport City are inside the Spoiler horizon and Route 110 and Mauville City are not

#### Scenario: Dewford waits for badge 1
- **WHEN** Progress has 0 badges
- **THEN** Dewford Town, Granite Cave, Slateport City and Route 116 are not inside the Spoiler horizon

#### Scenario: Mauville after badge 2
- **WHEN** Progress has badges 1 and 2
- **THEN** Route 110 and Mauville City are inside the Spoiler horizon and Verdanturf Town and Route 111 are not

### Requirement: Progress seeded per guest
Each guest SHALL have at most one Progress row. The first read of a guest's Progress SHALL seed it from `priv/progress.json`, safely when two reads race. Later reads and imports SHALL NOT overwrite it. The import SHALL seed game data only. Rows that existed before guests SHALL belong to the guest id `legacy`.

#### Scenario: New guest seeded
- **WHEN** a guest with no Progress has its Progress read
- **THEN** it has 0 badges, a Team of one level 5 Mudkip, location Littleroot Town and humor 75

#### Scenario: Existing Progress kept
- **WHEN** a guest's Progress has 1 badge and the import runs again
- **THEN** that guest's Progress still has 1 badge

#### Scenario: Import seeds game data only
- **WHEN** the release migrate runs twice on an empty database
- **THEN** the game data is loaded, no Progress row exists, and the second run changes no row counts

#### Scenario: Legacy rows kept
- **WHEN** the guest migration runs over an existing turn and Progress row
- **THEN** both rows have guest id `legacy` and no row is lost

### Requirement: Learnsets for Emerald
The fetch task SHALL write `priv/data/learnsets.json` with one row per species, move, learn method and level (a move can be learned at two levels, such as Aggron's Harden at 1 and 4) from the PokeAPI `emerald` version group, keeping only the `level-up` method in this change. The import SHALL load it into a `learnsets` table in the same transaction as the other game tables.

#### Scenario: Learnset parsed from a PokeAPI fixture
- **WHEN** the learnset parser reads a Mudkip `pokemon` fixture whose moves list `water-gun` at level 10 for `emerald` and at level 7 for another version group
- **THEN** it returns one `water-gun` row for Mudkip at level 10 with method `level-up`
- **AND** no row from another version group

#### Scenario: Machine moves left out
- **WHEN** the fixture lists a move with method `machine` for `emerald`
- **THEN** the parser returns no row for it

#### Scenario: Mudkip's learnset is queryable
- **WHEN** the committed data is imported and Mudkip's level-up moves are queried in level order
- **THEN** they start with Tackle 1, Growl 1, Mud-Slap 6, Water Gun 10 and Bide 15

#### Scenario: Import stays idempotent
- **WHEN** the import runs twice
- **THEN** the `learnsets` table has the same row count after both runs

### Requirement: Walkthrough notes from a committed file
`priv/data/walkthrough_notes.json` SHALL hold one note per listed location from Littleroot Town to Mauville City, each with `location`, `badges_required` and `text`. The import SHALL load it into a `walkthrough_notes` table and SHALL fail when a note's location is not in `locations.json` or its `badges_required` is below its location's. A note's text SHALL NOT name any listed location whose `badges_required` is above the note's own, nor any name on the spoiler forbidden list.

#### Scenario: One note per listed location
- **WHEN** the committed data is imported
- **THEN** `walkthrough_notes` has 21 rows, one per row of `locations.json`, each with the location's `badges_required`

#### Scenario: Note for an unlisted location
- **WHEN** the import reads a notes fixture with a note for Verdanturf Town
- **THEN** the import fails and no table is changed

#### Scenario: Note naming a later place
- **WHEN** the note checker reads a Rustboro City note (0 badges) that says "head to Route 116", or a Slateport City note (1 badge) that says "head north to Mauville City"
- **THEN** it reports each note as naming a place past its horizon

### Requirement: Humor dial written to Progress
Maya SHALL write a Guest's Humor dial to that Guest's Progress row only, as an integer 0 to 100.

#### Scenario: Humor changes for one Guest
- **WHEN** guest A's humor is set to 60
- **THEN** guest A's Progress has humor 60 and guest B's Progress keeps humor 75
