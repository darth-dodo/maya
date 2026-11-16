## ADDED Requirements

### Requirement: Team editor from a Team chip
Each `.mon` chip in `#team` SHALL be a button whose accessible name is "Edit " then the member's name and level. Tapping it while the Talk moment is idle SHALL open `#team-editor` for that member, with a heading naming it and buttons to change its level, set it as lead, move it to the PC box and remove it, plus a "PC box" button and a Close button. Close, Escape or a tap on another chip SHALL close or switch the editor.

#### Scenario: Open the editor
- **WHEN** a Guest whose Team is Mudkip 16 and Wingull 9 taps the Wingull chip while idle
- **THEN** `#team-editor` is shown with the heading "Wingull Lv 9" and the buttons "Save level", "Set as lead", "Move to PC box", "Remove", "PC box" and "Close"

#### Scenario: Close the editor
- **WHEN** the editor is open and the Guest taps Close or presses Escape
- **THEN** `#team-editor` is gone and focus is back on the chip that opened it

#### Scenario: Not while talking
- **WHEN** `#talk-screen` `data-state` is `recording`, `waiting` or `speaking` and a Team chip is tapped
- **THEN** no editor opens
- **AND** an editor that was open closes when a hold starts

### Requirement: Editor actions write Events
Each editor action SHALL write exactly the Event the same voice request writes (`set_level`, `set_lead`, `deposited`, `released`, `withdrawn`, with the member's `slot`), through the one Events path, so voice and screen give the same Progress. The editor SHALL show the confirm or refused line in a polite live region, update `#team` and the Team summary without a reload, and offer an Undo button after a confirm that logs `undo`.

#### Scenario: Change a level
- **WHEN** the Guest sets Wingull's level to 11 in the editor and taps Save level
- **THEN** one `set_level` Event is written, the chip reads "Wingull Lv 11", and the editor shows "Wingull is level 11 now."

#### Scenario: Level out of range
- **WHEN** the Guest saves level 0 or 101
- **THEN** the editor shows "Levels go from 1 to 100." and no Event is written

#### Scenario: Set as lead
- **WHEN** the Guest taps Set as lead on Wingull
- **THEN** `#team` lists Wingull first and the Team summary starts with "Wingull"

#### Scenario: Move to the PC box
- **WHEN** the Guest taps Move to PC box on Wingull
- **THEN** Wingull's chip is gone, one `deposited` Event is written, and the editor shows "Wingull sent to the PC."

#### Scenario: Remove
- **WHEN** the Guest taps Remove on Wingull
- **THEN** one `released` Event is written, the chip is gone, and the editor shows "Wingull released from the Team."

#### Scenario: Undo
- **WHEN** the Guest taps Undo after any confirmed action
- **THEN** the Team and PC box are as they were before it and `#team` shows that

#### Scenario: The last Team member
- **WHEN** the Team is only Mudkip and the Guest taps Move to PC box
- **THEN** the editor shows "Your Team needs at least one Pokémon." and Mudkip stays

#### Scenario: Same result as voice
- **WHEN** one Guest moves Wingull to the PC box in the editor and another Guest with the same Progress logs `deposited` Wingull by voice
- **THEN** both Guests have the same Team and PC box

### Requirement: PC box in the editor
The "PC box" button SHALL list the Guest's PC box members in order, each with its name, level and a "Withdraw" button whose accessible name is "Withdraw " then the name and level; an empty PC box SHALL read "The PC box is empty." Withdraw SHALL write a `withdrawn` Event with that member's PC box slot. The trainer card itself SHALL still never show the PC box.

#### Scenario: View and withdraw
- **WHEN** the PC box holds Lotad 6, the Team has 2 members, and the Guest taps PC box then Withdraw Lotad Lv 6
- **THEN** `#team` ends with a "Lotad Lv 6" chip and the editor shows "Lotad level 6 joined the Team."

#### Scenario: Withdraw with a full Team
- **WHEN** the Team has 6 and the Guest taps Withdraw on a PC box member
- **THEN** the editor shows the refused line naming one Team member to deposit first, and nothing changes

#### Scenario: Empty PC box
- **WHEN** the PC box is empty and the Guest taps PC box
- **THEN** the editor reads "The PC box is empty."

### Requirement: Editor is accessible and steady
Every editor control SHALL be a real button or labelled input at least 44px tall; opening the editor SHALL move focus into it. The editor SHALL use only `--maya-*` tokens in both themes, have no transition or animation under reduced motion, and open as an overlay that does not change the height of `#trainer-card` or `#talk-button`. It SHALL work with the Team summary collapsed or open, and `assets/js/talk_hook.js` SHALL have no diff.

#### Scenario: Targets and labels
- **WHEN** the editor is open at 375x667 in either theme
- **THEN** every button and the level input in `#team-editor` have a computed height of at least 44px and an accessible name
- **AND** the document scroll width is not larger than 375px

#### Scenario: Steady band
- **WHEN** the editor opens and closes at 375x667
- **THEN** `#trainer-card` and `#talk-button` have the same computed heights as with no editor

#### Scenario: Both themes on tokens
- **WHEN** the editor renders with `data-theme="light"` and with `data-theme="dark"`
- **THEN** its colours come only from `--maya-*` tokens and the colour gate test passes
- **AND** under `prefers-reduced-motion: reduce` nothing in `#team-editor` has a transition duration above 0 or an animation

#### Scenario: With the Team summary
- **WHEN** the Team summary is open and the Guest edits a member
- **THEN** the summary stays open and its names follow the new Team
