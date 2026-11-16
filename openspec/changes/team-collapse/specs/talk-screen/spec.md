## ADDED Requirements

### Requirement: Collapsible Team in the trainer band
The Team in `#trainer-card` SHALL be collapsed by default into one summary line with id `team-summary`, followed by a chevron hidden from screen readers. The line lists Team names in Team order with no levels: up to the first 3 names comma separated, then "+N" for the N remaining members; 3 or fewer members show all names with no "+N"; an empty Team shows "No Team yet". A tap on the summary SHALL show the full Team as `.mon` chips in `#team` and a second tap SHALL fold it back.

#### Scenario: Six members collapsed
- **WHEN** a Guest whose Team is Mudkip, Poochyena, Wingull, Ralts, Zigzagoon and Lotad opens `/talk`
- **THEN** `#team-summary` reads "Mudkip, Poochyena, Wingull +3" and the Team is collapsed
- **AND** `#team` still holds 6 `.mon` elements in the page

#### Scenario: Two members
- **WHEN** a Guest whose Team is Mudkip and Wingull opens `/talk`
- **THEN** `#team-summary` reads "Mudkip, Wingull" with no "+"

#### Scenario: Empty Team
- **WHEN** a Guest whose Team is empty opens `/talk`
- **THEN** `#team-summary` reads "No Team yet"

#### Scenario: Tap to open and close
- **WHEN** a Guest with 6 Team members taps `#team-summary` at 375x667
- **THEN** all 6 `.mon` chips are visible and the summary reports expanded
- **AND** a second tap hides them and the summary reports collapsed

### Requirement: Team summary fits one line and names everyone
The summary SHALL stay one line: when the names do not fit, they SHALL truncate with an ellipsis while the "+N" and the chevron stay fully visible. The summary's accessible name SHALL list the whole Team in order, "Team: " then every name comma separated, so screen readers get every name. It SHALL expose its expanded or collapsed state and be at least 44px tall.

#### Scenario: Six members at 375px
- **WHEN** `/talk` renders at 375x667 for a Guest with 6 Team members whose names do not fit the line
- **THEN** `#team-summary` is one line tall, its names part shows an ellipsis, and the "+3" and the chevron are fully inside the viewport
- **AND** the document scroll width is not larger than 375px

#### Scenario: Accessible name lists the whole Team
- **WHEN** a Guest whose Team is Mudkip, Poochyena, Wingull, Ralts, Zigzagoon and Lotad opens `/talk`
- **THEN** the accessible name of `#team-summary` is "Team: Mudkip, Poochyena, Wingull, Ralts, Zigzagoon, Lotad"

#### Scenario: Tap target and motion
- **WHEN** `/talk` renders at 375px wide in either theme
- **THEN** `#team-summary` has a computed height of at least 44px
- **AND** under `prefers-reduced-motion: reduce` nothing in `#trainer-card` has a transition duration above 0 or an animation
- **AND** `assets/js/talk_hook.js` has no diff

### Requirement: Team open state and steady band
Once open, the Team SHALL stay open through LiveView updates for the rest of the page view; each visit starts collapsed and nothing is stored. A change to the Team SHALL update the summary and the chips and SHALL NOT open or close the list. The Team SHALL use only `--maya-*` tokens in both themes and SHALL NOT animate its height.

#### Scenario: Open survives an update
- **WHEN** the Team is open and the page receives a LiveView update (a Talk moment change, a new turn or a Team change)
- **THEN** the Team is still open after the update

#### Scenario: A catch while collapsed updates the names
- **WHEN** the Team is collapsed as Mudkip and Wingull and the Guest catches Ralts
- **THEN** `#team-summary` reads "Mudkip, Wingull, Ralts" and the Team stays collapsed

#### Scenario: Collapsed band stays short
- **WHEN** `/talk` renders at 375x667 with the Team collapsed, once for a Guest with 1 Team member and once with 6
- **THEN** `#trainer-card` has the same computed height in both, and it is shorter than with the 6 member Team open

#### Scenario: Band steady in every moment
- **WHEN** `/talk` renders at 375px wide, with the Team collapsed and again open, and `#talk-screen` `data-state` is set to `idle`, `recording`, `waiting` and `speaking` in turn
- **THEN** the computed heights of `#trainer-card` and `#talk-button` are the same in every moment within each case
