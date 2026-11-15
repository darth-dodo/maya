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
The `locations` table SHALL list Littleroot Town, Route 101, Oldale Town, Route 103, Route 102, Petalburg City, Route 104, Petalburg Woods and Rustboro City, each with the badges required to talk about it.

#### Scenario: Locations up to Rustboro City
- **WHEN** the committed data is imported
- **THEN** exactly those nine locations exist, each with a badges required value

### Requirement: Progress seeded once
Progress SHALL be seeded from `priv/progress.json` only when no Progress exists, and a later import SHALL NOT overwrite it (ADR-006).

#### Scenario: Seed on an empty table
- **WHEN** the import runs with no Progress
- **THEN** Progress has 0 badges, a Team of one level 5 Mudkip, location Littleroot Town and humor 75

#### Scenario: Existing Progress kept
- **WHEN** Progress already has 1 badge and the import runs again
- **THEN** Progress still has 1 badge
