# events Specification

## Purpose
Turns what the Guest tells Maya about their game (a badge earned, a catch, an evolution, a level, a move) into Events that update their Progress, validated against Maya's own data, with undo of the last Event.

## Requirements

### Requirement: Log an Event
The agent SHALL have a `log_event` tool with a `kind` (`badge_earned`, `caught`, `evolved`, `level_up`, `moved` or `undo`) and `details`. A valid Event SHALL be written to the Guest's Events and applied to the Guest's Progress in one transaction, and the tool SHALL return a one line confirm that names only what the Guest said and the data confirms. Another Guest's Progress SHALL NOT change.

#### Scenario: Roxanne's badge
- **WHEN** a Guest with 0 badges logs `badge_earned` with leader Roxanne
- **THEN** the Guest's Progress has badge 1, the Next gym is Brawly, and the confirm is "Stone Badge logged. Mudkip would approve."
- **AND** one Event of kind `badge_earned` exists for that Guest

#### Scenario: Badge by number
- **WHEN** a Guest with 0 badges logs `badge_earned` with badge 1
- **THEN** the Guest's Progress has badge 1

#### Scenario: A catch joins the Team
- **WHEN** a Guest logs `caught` with species Ralts and level 4
- **THEN** the Team ends with Ralts at level 4 and the confirm names Ralts level 4

#### Scenario: A level up
- **WHEN** a Guest whose Team has Mudkip logs `level_up` with species Mudkip and level 13
- **THEN** Mudkip is level 13 on the Team and the confirm is "Mudkip level 13 logged."

#### Scenario: An evolution
- **WHEN** a Guest whose Team has Mudkip logs `evolved` from Mudkip to Marshtomp
- **THEN** that Team slot is Marshtomp at the same level

#### Scenario: A move
- **WHEN** a Guest with 1 badge logs `moved` to Dewford Town
- **THEN** the Guest's location is Dewford Town

#### Scenario: Other Guests untouched
- **WHEN** one Guest logs Roxanne's badge
- **THEN** another Guest still has 0 badges

### Requirement: Only the Next gym's badge
A badge SHALL be logged only when it is the Next gym's badge. A badge past the Next gym, an unknown leader and an unknown badge number SHALL get the same refusal, which names only the Next gym, so it never confirms that a later gym exists.

#### Scenario: A later badge
- **WHEN** a Guest with 0 badges logs `badge_earned` with leader Wattson, with leader Giovanni, or with badge 3
- **THEN** each is refused with "I can only log Roxanne's badge next." and Progress keeps 0 badges

### Requirement: Events are validated against Maya's data
An Event that Maya's data does not confirm SHALL be refused with one polite line, leaving Progress and Events unchanged. Species come from game data, levels are whole numbers 1 to 100, the Team holds at most 6, level ups and evolutions name a species on the Team, evolutions are ones the game data lists, and moves name a location inside the Spoiler horizon. A refusal SHALL NOT contain "beat" or "defeat".

#### Scenario: A badge already earned
- **WHEN** a Guest with badge 1 logs Roxanne's badge again
- **THEN** it is refused with "You already have the Stone Badge." and no Event is written

#### Scenario: Unknown species
- **WHEN** a Guest logs `caught` with species Agumon
- **THEN** it is refused and the Team is unchanged

#### Scenario: Level out of range
- **WHEN** a Guest logs `level_up` with level 0, 101 or "thirteen"
- **THEN** it is refused with "Levels go from 1 to 100."

#### Scenario: Full Team
- **WHEN** a Guest with 6 on the Team logs `caught`
- **THEN** it is refused and the Team keeps 6

#### Scenario: A move past the horizon
- **WHEN** a Guest with 1 badge logs `moved` to Mauville City
- **THEN** it is refused with a line that names no place and the location is unchanged

### Requirement: Undo the last Event
`log_event` with kind `undo` SHALL restore the Guest's Progress from before their last Event and remove that Event, in one transaction. With no Event left it SHALL say there is nothing to undo.

#### Scenario: Undo a badge
- **WHEN** a Guest logs Roxanne's badge and then logs `undo`
- **THEN** the Guest has 0 badges again, the Next gym is Roxanne and the Event is gone

#### Scenario: Nothing to undo
- **WHEN** a Guest with no Events logs `undo`
- **THEN** the reply is "There is nothing to undo." and Progress is unchanged
