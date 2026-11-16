## ADDED Requirements

### Requirement: Walkthrough notes from a committed file
`priv/data/walkthrough_notes.json` SHALL hold one note per listed location from Littleroot Town to Mauville City, each with `location`, `badges_required` and `text`. The import SHALL load it into a `walkthrough_notes` table and SHALL fail when a note's location is not in `locations.json` or its `badges_required` is below its location's. A note's text SHALL NOT name any listed location whose `badges_required` is above the note's own, nor any name on the spoiler forbidden list.

#### Scenario: One note per listed location
- **WHEN** the committed data is imported
- **THEN** `walkthrough_notes` has 21 rows, one per row of `locations.json`, each with the location's `badges_required`

#### Scenario: Note for an unlisted location
- **WHEN** the import reads a notes fixture with a note for Verdanturf Town
- **THEN** the import fails and no table is changed

#### Scenario: Note naming a later place
- **WHEN** the note checker reads a Rustboro City note (0 badges) that says "head to Route 116", or a Dewford Town note (1 badge) that says "sail on to Slateport City"
- **THEN** it reports each note as naming a place past its horizon

### Requirement: Humor dial written to Progress
Maya SHALL write a Guest's Humor dial to that Guest's Progress row only, as an integer 0 to 100.

#### Scenario: Humor changes for one Guest
- **WHEN** guest A's humor is set to 60
- **THEN** guest A's Progress has humor 60 and guest B's Progress keeps humor 75

## MODIFIED Requirements

### Requirement: Hand-written locations
The `locations` table SHALL list Littleroot Town, Route 101, Oldale Town, Route 103, Route 102, Petalburg City, Route 104, Petalburg Woods and Rustboro City with badges required 0; Route 116, Rusturf Tunnel, Route 105, Route 106, Dewford Town and Granite Cave with badges required 1; and Route 107, Route 108, Route 109, Slateport City, Route 110 and Mauville City with badges required 2. Granite Cave SHALL map to its first floor only. Every other location stays unlisted, so it is past the Spoiler horizon (fail closed). Every deploy reloads the table from the committed file.

#### Scenario: Locations up to Rustboro City
- **WHEN** the committed data is imported
- **THEN** Littleroot Town to Rustboro City, nine locations, each have badges required 0

#### Scenario: Locations up to Mauville City
- **WHEN** the committed data is imported
- **THEN** exactly those twenty-one locations exist, each with a badges required value

#### Scenario: Through Dewford after badge 1
- **WHEN** Progress has badge 1
- **THEN** Route 104, Dewford Town and Granite Cave are inside the Spoiler horizon and Slateport City, Route 110 and Mauville City are not

#### Scenario: Dewford waits for badge 1
- **WHEN** Progress has 0 badges
- **THEN** Dewford Town, Granite Cave and Route 116 are not inside the Spoiler horizon

#### Scenario: Mauville after badge 2
- **WHEN** Progress has badges 1 and 2
- **THEN** Slateport City, Route 110 and Mauville City are inside the Spoiler horizon and Verdanturf Town and Route 111 are not
