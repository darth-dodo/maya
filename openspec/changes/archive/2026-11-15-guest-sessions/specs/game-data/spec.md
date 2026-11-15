## REMOVED Requirements

### Requirement: Progress seeded once
**Reason**: Progress belongs to a guest now (#61, ADR-008); the import no longer seeds a single row.
**Migration**: See "Progress seeded per guest".

## ADDED Requirements

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
