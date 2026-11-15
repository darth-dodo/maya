# talk-screen Specification

## Purpose
The screen at `/` the player talks to Maya on: the Talk button and its state machine, the Conversation list and the voice down note.

## Requirements

### Requirement: Talk screen at the root
The page at `/` SHALL be the Talk screen: a Talk button with id `talk-button`, a Conversation list with id `conversation` showing recent turns (Question and Answer text) in order, and a top panel holding the Emerald Poké Ball, the tide hero, the heading, the tagline and the Mudkip hype line. It SHALL keep the strict Content-Security-Policy unchanged: audio travels over the existing LiveView socket only.

#### Scenario: Empty Conversation
- **WHEN** a visitor opens `/` and no turns are stored
- **THEN** `#talk-button` exists and `#conversation` has no `.turn` element

#### Scenario: Stored turns are shown
- **WHEN** a visitor opens `/` and a turn with Question "Where is Ralts" is stored
- **THEN** `#conversation` has one `.turn` whose `.question` reads "Where is Ralts" and whose `.answer` reads the stored Answer

#### Scenario: CSP unchanged
- **WHEN** a visitor opens `/`
- **THEN** the `content-security-policy` header still has `connect-src 'self'` and no new origin

### Requirement: Talk button state machine
The Talk button SHALL run as an explicit state machine with the states `idle`, `recording`, `uploading`, `waiting` and `speaking`, shown in its `data-state` attribute. Pressing and holding records; releasing sends exactly one Question as one upload. Pressing while `speaking` is a barge-in that stops audio at once and starts recording. The button SHALL report the mic release and playback start timings back to the server.

#### Scenario: Idle on load
- **WHEN** a visitor opens `/`
- **THEN** `#talk-button` has `data-state="idle"` and is bound to the Talk hook

#### Scenario: One upload per hold
- **WHEN** one clip is uploaded as the Question
- **THEN** the Conversation receives exactly one Question
- **AND** the upload accepts at most one entry of at most 1 MB

### Requirement: Voice down note
When the voice is down the Talk screen SHALL show the note "voice is down" next to the affected turn, or on its own when no Question was heard.

#### Scenario: Note shown
- **WHEN** the Conversation reports that TTS failed for a turn
- **THEN** that `.turn` contains an element `.voice-down` with the text "voice is down"
