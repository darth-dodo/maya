## ADDED Requirements

### Requirement: Collapsible Team in the trainer band
The Team in `#trainer-card` SHALL be collapsed by default into one summary line with id `team-summary`: the lead Pokémon (first in the Team) as "Name Lv N", then " + K more" when the Team has K more members, and a chevron hidden from screen readers. A tap on the summary SHALL show the full Team as `.mon` chips in `#team` and a second tap SHALL fold it back.

#### Scenario: Collapsed by default
- **WHEN** a Guest with a Team of Mudkip Lv 14 and 5 more members opens `/talk`
- **THEN** `#team-summary` reads "Mudkip Lv 14 + 5 more" and the Team is collapsed
- **AND** `#team` still holds 6 `.mon` elements in the page

#### Scenario: Team of one
- **WHEN** a new Guest opens `/talk`
- **THEN** `#team-summary` reads "Mudkip Lv 5" with no "more"

#### Scenario: Tap to open and close
- **WHEN** a Guest with 6 Team members taps `#team-summary` at 375x667
- **THEN** all 6 `.mon` chips are visible and the summary reports expanded
- **AND** a second tap hides them and the summary reports collapsed

### Requirement: Team open state and steady band
Once open, the Team SHALL stay open through LiveView updates for the rest of the page view; a reload starts collapsed. A change to the Team SHALL update the summary and the chips and SHALL NOT open or close the list. The summary SHALL expose its expanded or collapsed state to assistive technology and be at least 44px tall. The Team SHALL use only `--maya-*` tokens in both themes and SHALL NOT animate its height.

#### Scenario: Open survives an update
- **WHEN** the Team is open and the page receives a LiveView update (a Talk moment change, a new turn or a Team change)
- **THEN** the Team is still open after the update

#### Scenario: New member never opens the list
- **WHEN** the Team is collapsed with 2 members and a third member joins
- **THEN** `#team-summary` reads "+ 2 more" and the Team stays collapsed

#### Scenario: Collapsed band stays short
- **WHEN** `/talk` renders at 375x667 with the Team collapsed, once for a Guest with 1 Team member and once with 6
- **THEN** `#trainer-card` has the same computed height in both, and it is shorter than with the 6 member Team open

#### Scenario: Band steady in every moment
- **WHEN** `/talk` renders at 375px wide, with the Team collapsed and again open, and `#talk-screen` `data-state` is set to `idle`, `recording`, `waiting` and `speaking` in turn
- **THEN** the computed heights of `#trainer-card` and `#talk-button` are the same in every moment within each case

#### Scenario: Tap target and motion
- **WHEN** `/talk` renders at 375px wide in either theme
- **THEN** `#team-summary` has a computed height of at least 44px
- **AND** under `prefers-reduced-motion: reduce` nothing in `#trainer-card` has a transition duration above 0 or an animation
- **AND** `assets/js/talk_hook.js` has no diff
