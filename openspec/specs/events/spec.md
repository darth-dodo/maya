# events Specification

## Purpose
Turns what the Guest tells Maya about their game (a badge earned, a catch, an evolution, a level, a move, a release) into Events that update their Progress, validated against Maya's own data, with undo of the last Event.

## Requirements

### Requirement: Log an Event
The agent SHALL have a `log_event` tool with a `kind` (`badge_earned`, `caught`, `evolved`, `set_level`, `moved`, `released`, `deposited`, `withdrawn`, `set_lead`, `set_team` or `undo`) and `details`. Events SHALL also accept `level_up` (as before) from other callers, but the tool SHALL NOT offer it. A valid Event SHALL be written to the Guest's Events and applied to the Guest's Progress in one transaction, and the tool SHALL return a one line confirm that names only what the Guest said and the data confirms. Another Guest's Progress SHALL NOT change.

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

#### Scenario: The tool offers set_level, not level_up
- **WHEN** the agent's tool definitions are built
- **THEN** the `log_event` kind list holds `set_level`, `deposited`, `withdrawn`, `set_lead` and `set_team`, and not `level_up`

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
An Event that Maya's data does not confirm SHALL be refused with one polite line, leaving Progress and Events unchanged. Species come from game data, levels are whole numbers 1 to 100, the Team holds at most 6 (a catch past 6 goes to the PC box, never refused), `deposited` and `set_team` never leave the Team empty, level ups and evolutions name a species on the Team, evolutions are ones the game data lists, and moves name a location inside the Spoiler horizon. A refusal SHALL NOT contain "beat" or "defeat".

#### Scenario: A badge already earned
- **WHEN** a Guest with badge 1 logs Roxanne's badge again
- **THEN** it is refused with "You already have the Stone Badge." and no Event is written

#### Scenario: Unknown species
- **WHEN** a Guest logs `caught` with species Agumon, or `set_team` naming Agumon
- **THEN** it is refused with "That Pokémon is not in my data." and the Team is unchanged

#### Scenario: Level out of range
- **WHEN** a Guest logs `level_up` or `set_level` with level 0, 101 or "thirteen"
- **THEN** it is refused with "Levels go from 1 to 100."

#### Scenario: A move past the horizon
- **WHEN** a Guest with 1 badge logs `moved` to Mauville City
- **THEN** it is refused with a line that names no place and the location is unchanged

### Requirement: A repeated catch is logged once
A `caught` Event with the same species and level as a catch the Guest logged in the last 2 minutes, while that Pokémon is still on the Team or in the PC box, SHALL NOT be written again: Progress and Events stay as they are and the confirm says it is already logged. A `deposited` or `withdrawn` Event with the same kind and species as the Guest's last Event, written in the last 2 minutes, SHALL NOT be written again either. This holds whether the repeat comes in the same turn or a later one. Other kinds SHALL always apply, apart from the no-change rule for Team changes.

#### Scenario: The same catch twice
- **WHEN** a Guest logs `caught` Poochyena level 9 and the agent logs it again in the same or the next turn
- **THEN** the Team has one Poochyena, there is one Event, and the second confirm is "Poochyena level 9 is already logged."

#### Scenario: A pair re-logged
- **WHEN** a Guest logs Poochyena level 9, then Wingull level 9, then Poochyena level 9 again inside the window
- **THEN** the Team has one Poochyena and one Wingull

#### Scenario: A catch after a release
- **WHEN** a Guest releases Poochyena level 9 and then logs a catch of Poochyena level 9 inside the window
- **THEN** the catch is logged, because that Poochyena is no longer on the Team or in the PC box

#### Scenario: The same deposit twice
- **WHEN** a Guest whose Team has Wingull twice logs `deposited` Wingull and the agent logs it again in the same turn
- **THEN** one Wingull is in the PC box, one is still on the Team, there is one Event, and the second confirm is "Wingull is already in the PC."

#### Scenario: A deposit after an undo
- **WHEN** a Guest logs `deposited` Wingull, then `undo`, then `deposited` Wingull inside the window
- **THEN** Wingull is in the PC box, because the undo removed the first Event

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

### Requirement: Deposit and withdraw
`deposited` SHALL move one Team member of the named species to the end of the PC box, and `withdrawn` one PC box member to the end of the Team, keeping its level. A species not where it is moved from, or the last Team member, SHALL be refused. A withdraw with 6 on the Team SHALL be refused, naming the lowest level Team member (ties to the last) to deposit first.

#### Scenario: Deposit
- **WHEN** a Guest whose Team is Mudkip 16 and Wingull 9 logs `deposited` Wingull
- **THEN** the Team is Mudkip 16, the PC box ends with Wingull 9, and the confirm is "Wingull sent to the PC."

#### Scenario: The last Team member
- **WHEN** a Guest whose Team is only Mudkip logs `deposited` Mudkip
- **THEN** it is refused with "Your Team needs at least one Pokémon." and nothing changes

#### Scenario: Not on the Team
- **WHEN** a Guest logs `deposited` with a species not on the Team
- **THEN** it is refused with "I can only deposit a Pokémon on your Team."

#### Scenario: Withdraw
- **WHEN** a Guest whose Team has 2 members and whose PC box has Lotad 6 logs `withdrawn` Lotad
- **THEN** the Team ends with Lotad 6, the PC box no longer holds it, and the confirm is "Lotad level 6 joined the Team."

#### Scenario: Withdraw with a full Team
- **WHEN** a Guest whose Team is Mudkip 16, Taillow 12, Wingull 9, Ralts 7, Zigzagoon 7 and Poochyena 10 logs `withdrawn` Lotad from the PC box
- **THEN** it is refused with "The Team is full at 6. Deposit one first, maybe Zigzagoon." and nothing changes

#### Scenario: Not in the PC box
- **WHEN** a Guest logs `withdrawn` with a species not in the PC box
- **THEN** it is refused with "I can only withdraw a Pokémon in the PC."

### Requirement: Set the lead
`set_lead` with a species SHALL move one Team member of that species to the front of the Team; the others SHALL keep their order. A species not on the Team SHALL be refused, and one only in the PC box SHALL be refused with a line that says to withdraw it first.

#### Scenario: New lead
- **WHEN** a Guest whose Team is Mudkip, Taillow and Wingull logs `set_lead` Wingull
- **THEN** the Team is Wingull, Mudkip, Taillow and the confirm is "Wingull leads the Team now."

#### Scenario: In the PC box
- **WHEN** a Guest whose PC box holds Lotad and whose Team does not logs `set_lead` Lotad
- **THEN** it is refused with "Lotad is in the PC, withdraw it first." and nothing changes

### Requirement: Set the whole Team
`set_team` with a list of 1 to 6 members (species, and a level that may be left out) SHALL make the Team exactly that list, in that order, in one Event. Each named member SHALL be taken from the Team, then the PC box, at the named level; a level left out keeps that member's level; a species on neither is added and needs a level. Team members not named SHALL go to the end of the PC box in Team order, never deleted. An empty list or more than 6 SHALL be refused.

#### Scenario: My Team is
- **WHEN** a Guest whose Team is Mudkip 14, Wingull 9 and Ralts 7 and whose PC box holds Taillow 11 logs `set_team` Mudkip 16, Taillow 12
- **THEN** the Team is Mudkip 16 and Taillow 12, the PC box holds Wingull 9 and Ralts 7 and no Taillow, and the confirm is "Team set: Mudkip level 16, Taillow level 12. 2 sent to the PC."

#### Scenario: Undo a whole Team
- **WHEN** that Guest then logs `undo`
- **THEN** the Team is Mudkip 14, Wingull 9 and Ralts 7 again and the PC box holds Taillow 11

#### Scenario: A new species with no level
- **WHEN** a Guest logs `set_team` naming Shroomish with no level, and Shroomish is on neither the Team nor in the PC box
- **THEN** it is refused with "What level is Shroomish?" and nothing changes

#### Scenario: Too many or none
- **WHEN** a Guest logs `set_team` with 7 members, or with none
- **THEN** it is refused with "A Team holds 1 to 6 Pokémon." and nothing changes

### Requirement: Set a level
`set_level` with a species and a level SHALL set that level on one member of that species, on the Team first and else in the PC box, whether it goes up or down. A species on neither SHALL be refused.

#### Scenario: A lower level
- **WHEN** a Guest whose Team has Poochyena 12 logs `set_level` Poochyena 9
- **THEN** Poochyena is level 9 and the confirm is "Poochyena is level 9 now."

#### Scenario: In the PC box
- **WHEN** a Guest whose PC box holds Lotad 6 logs `set_level` Lotad 8
- **THEN** Lotad is level 8 in the PC box

#### Scenario: Neither
- **WHEN** a Guest logs `set_level` with a species on neither the Team nor in the PC box
- **THEN** it is refused with "I can only set a level for a Pokémon on your Team or in the PC."

### Requirement: Pick a member by slot
`deposited`, `set_lead`, `set_level` and `released` SHALL accept an optional `slot` (a 1-based Team position) and `withdrawn` an optional `slot` (a 1-based PC box position), so one of two same-species members can be picked. When the member at that slot is not the named species, the Event SHALL be refused and nothing changes.

#### Scenario: The second Poochyena
- **WHEN** a Guest whose Team is Poochyena 9, Mudkip 16 and Poochyena 12 logs `set_level` Poochyena 13 with slot 3
- **THEN** the Team is Poochyena 9, Mudkip 16 and Poochyena 13

#### Scenario: A stale slot
- **WHEN** a Guest logs `deposited` Wingull with slot 2 and the Team's slot 2 holds Taillow
- **THEN** it is refused with "That Pokémon moved, so nothing changed." and nothing changes

### Requirement: A Team change that changes nothing
A `set_lead`, `set_team` or `set_level` Event that would leave the Team and PC box exactly as they are SHALL NOT be written: the confirm says it is already so, and a following `undo` undoes the Event before it.

#### Scenario: Already the lead
- **WHEN** a Guest whose Team starts with Mudkip logs `set_lead` Mudkip
- **THEN** no Event is written and the confirm is "Mudkip already leads the Team."

#### Scenario: The same Team again
- **WHEN** a Guest logs `set_team` Mudkip 16, Taillow 12 twice in one turn
- **THEN** there is one `set_team` Event and the second confirm is "That is already your Team."
