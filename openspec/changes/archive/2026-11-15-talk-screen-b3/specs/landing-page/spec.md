# Spec Delta

## MODIFIED Requirements

### Requirement: Maya identity on the home page
The home page SHALL name Maya once, in the app header link to `/`, and SHALL have exactly one top-level heading, "Talk to Maya", with id `talk-heading`, visually hidden so it does not repeat the header. It SHALL NOT show the old `#maya-heading` or `#tagline`.

#### Scenario: Visitor opens the home page
- **WHEN** a visitor requests `/`
- **THEN** the response is HTTP 200
- **AND** the header link to `/` reads "Maya"
- **AND** the page has one `h1`, `#talk-heading`, reading "Talk to Maya"
- **AND** the page has no `#maya-heading` and no `#tagline`

## ADDED Requirements

### Requirement: Poké Ball in the trainer card
The home page SHALL show an Emerald edition Poké Ball (green, white and black) drawn in CSS without images, in an element with id `pokeball` and class `pokeball-emerald`, inside the trainer card `#trainer-card`. The old hero `#maya-hero` SHALL NOT be shown.

#### Scenario: Poké Ball is present
- **WHEN** a visitor requests `/`
- **THEN** the element `#pokeball` exists
- **AND** it contains no `img` element

#### Scenario: Emerald ball in the trainer card
- **WHEN** a visitor requests `/`
- **THEN** `#trainer-card #pokeball` has the class `pokeball-emerald`
- **AND** the page has no `#maya-hero`

### Requirement: Badge case in the trainer card
The home page SHALL show, in the trainer card, a badge case with id `badge-case` holding exactly 8 badge slots, each labelled only by its number and marked earned or not from the Guest's Progress. It SHALL NOT name any badge, and SHALL NOT name any gym or gym leader past the Guest's Next gym. The badge case stays shown once the Conversation has a turn.

#### Scenario: Eight empty slots
- **WHEN** a new Guest requests `/`
- **THEN** `#badge-case` contains exactly 8 elements with class `badge-slot`
- **AND** every slot has `data-earned="false"`
- **AND** the slots are labelled "Badge 1 of 8" through "Badge 8 of 8"

#### Scenario: No spoilers
- **WHEN** a new Guest requests `/`
- **THEN** the page names Roxanne, the Next gym, and none of the later Hoenn gym leaders (Brawly, Wattson, Flannery, Norman, Winona, Tate, Liza, Juan)
- **AND** none of the Hoenn badge names (Stone, Knuckle, Dynamo, Heat, Balance, Feather, Mind, Rain) followed by "Badge"

#### Scenario: Shown once the Conversation starts
- **WHEN** a visitor requests `/` and the Conversation has a turn
- **THEN** the page still has `#badge-case`

## REMOVED Requirements

### Requirement: Mudkip hype
**Reason**: The line lived in the old hero, which the B3 trainer card replaces (#66).
**Migration**: None; Mudkip hype stays a personality dial in Maya's Answers.

### Requirement: Poke Ball themed hero
**Reason**: The hero goes; the ball moves into the trainer card (#66).
**Migration**: See "Poké Ball in the trainer card".

### Requirement: Spoiler-free badge case
**Reason**: The badge case moves into the trainer card, shows earned badges and allows the Next gym (#66).
**Migration**: See "Badge case in the trainer card".
