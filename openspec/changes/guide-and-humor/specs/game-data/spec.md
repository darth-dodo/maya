## ADDED Requirements

### Requirement: Walkthrough notes from a committed file
`priv/data/walkthrough_notes.json` SHALL hold one note per listed location from Littleroot Town to Dewford Town, each with `location`, `badges_required` and `text`. The import SHALL load it into a `walkthrough_notes` table and SHALL fail when a note's location is not in `locations.json` or its `badges_required` is below its location's. A note's text SHALL NOT name any listed location whose `badges_required` is above the note's own, nor any name on the spoiler forbidden list.

#### Scenario: One note per listed location
- **WHEN** the committed data is imported
- **THEN** `walkthrough_notes` has 14 rows, one per row of `locations.json`, each with the location's `badges_required`

#### Scenario: Note for an unlisted location
- **WHEN** the import reads a notes fixture with a note for Mauville City
- **THEN** the import fails and no table is changed

#### Scenario: Note naming a later place
- **WHEN** the note checker reads a Rustboro City note (0 badges) that says "head to Route 116"
- **THEN** it reports the note as naming a place past its horizon

### Requirement: Humor dial written to Progress
Maya SHALL write a Guest's Humor dial to that Guest's Progress row only, as an integer 0 to 100.

#### Scenario: Humor changes for one Guest
- **WHEN** guest A's humor is set to 60
- **THEN** guest A's Progress has humor 60 and guest B's Progress keeps humor 75
