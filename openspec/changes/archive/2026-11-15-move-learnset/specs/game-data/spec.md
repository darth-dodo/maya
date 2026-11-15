## ADDED Requirements

### Requirement: Learnsets for Emerald
The fetch task SHALL write `priv/data/learnsets.json` with one row per species, move and learn method from the PokeAPI `emerald` version group, keeping only the `level-up` method in this change, with the level learned. The import SHALL load it into a `learnsets` table in the same transaction as the other game tables.

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
