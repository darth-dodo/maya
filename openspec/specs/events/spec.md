# events Specification

## Purpose
Turns what the Guest tells Maya about their game (a badge earned, a catch, an evolution, a level, a move, a release) into Events that update their Progress, validated against Maya's own data, with undo of the last Event.

## Requirements

### Requirement: Log an Event
The agent SHALL have a `log_event` tool with a `kind` (`badge_earned`, `caught`, `evolved`, `level_up`, `moved`, `released` or `undo`) and `details`. A valid Event SHALL be written to the Guest's Events and applied to the Guest's Progress in one transaction, and the tool SHALL return a one line confirm that names only what the Guest said and the data confirms. Another Guest's Progress SHALL NOT change.

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

#### Scenario: A catch with a full Team goes to the PC
- **WHEN** a Guest with 6 on the Team logs `caught` with species Lotad and level 6
- **THEN** the Team keeps its 6, Lotad level 6 is in the Guest's PC box, and the confirm is "Lotad level 6 sent to the PC, the Team is full at 6."
- **AND** the trainer card shows only the Team, never the PC box

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
An Event that Maya's data does not confirm SHALL be refused with one polite line, leaving Progress and Events unchanged. Species come from game data, levels are whole numbers 1 to 100, the Team holds at most 6 (a catch past 6 goes to the PC box, never refused), level ups and evolutions name a species on the Team, evolutions are ones the game data lists, and moves name a location inside the Spoiler horizon. A refusal SHALL NOT contain "beat" or "defeat".

#### Scenario: A badge already earned
- **WHEN** a Guest with badge 1 logs Roxanne's badge again
- **THEN** it is refused with "You already have the Stone Badge." and no Event is written

#### Scenario: Unknown species
- **WHEN** a Guest logs `caught` with species Agumon
- **THEN** it is refused and the Team is unchanged

#### Scenario: Level out of range
- **WHEN** a Guest logs `level_up` with level 0, 101 or "thirteen"
- **THEN** it is refused with "Levels go from 1 to 100."

#### Scenario: A move past the horizon
- **WHEN** a Guest with 1 badge logs `moved` to Mauville City
- **THEN** it is refused with a line that names no place and the location is unchanged

### Requirement: A repeated catch is logged once
A `caught` Event with the same species and level as a catch the Guest logged in the last 2 minutes, while that Pokémon is still on the Team or in the PC box, SHALL NOT be written again: Progress and Events stay as they are and the confirm says it is already logged. This holds whether the repeat comes in the same turn or a later one. Other kinds SHALL always apply (they do not add to the Team, and `undo` and `released` are corrections).

#### Scenario: The same catch twice
- **WHEN** a Guest logs `caught` Poochyena level 9 and the agent logs it again in the same or the next turn
- **THEN** the Team has one Poochyena, there is one Event, and the second confirm is "Poochyena level 9 is already logged."

#### Scenario: A pair re-logged
- **WHEN** a Guest logs Poochyena level 9, then Wingull level 9, then Poochyena level 9 again inside the window
- **THEN** the Team has one Poochyena and one Wingull

#### Scenario: A catch after a release
- **WHEN** a Guest releases Poochyena level 9 and then logs a catch of Poochyena level 9 inside the window
- **THEN** the catch is logged, because that Poochyena is no longer on the Team or in the PC box

### Requirement: Release a Pokémon
`log_event` with kind `released` and a species SHALL remove one Pokémon of that species from the Team, or from the PC box when none is on the Team, so a duplicate can be fixed. A species in neither SHALL be refused.

#### Scenario: Fix a duplicate
- **WHEN** a Guest whose Team has Poochyena twice logs `released` with species Poochyena
- **THEN** the Team has one Poochyena and the confirm is "Poochyena released from the Team."

#### Scenario: Nothing to release
- **WHEN** a Guest logs `released` with a species on neither the Team nor in the PC box
- **THEN** it is refused with "I can only release a Pokémon on your Team or in the PC."

### Requirement: Undo the last Event
`log_event` with kind `undo` SHALL restore the Guest's Progress (badges, Team, PC box and location) from before their last Event and remove that Event, in one transaction. With no Event left it SHALL say there is nothing to undo.

#### Scenario: Undo a badge
- **WHEN** a Guest logs Roxanne's badge and then logs `undo`
- **THEN** the Guest has 0 badges again, the Next gym is Roxanne and the Event is gone

#### Scenario: Nothing to undo
- **WHEN** a Guest with no Events logs `undo`
- **THEN** the reply is "There is nothing to undo." and Progress is unchanged
