# Spec Delta

## ADDED Requirements

### Requirement: Hold end
The first `pointerup` or `pointercancel` SHALL end a hold and any later one SHALL do nothing; a lost pointer capture alone SHALL NOT end a hold. A server re-render SHALL NOT change the button's own state. Each hold SHALL report how it ended (`pointerup` or `pointercancel`), its length in ms and whether capture was lost first, and the server SHALL log that report at info level with no audio or text; any other report is ignored.

#### Scenario: Hold end logged
- **WHEN** the Talk button reports a hold that ended by `pointercancel` after 840 ms with capture lost and the mic live after 120 ms
- **THEN** the server logs "hold ended by pointercancel after 840 ms, lost capture: true, mic open: 120 ms" at info level

#### Scenario: Hold ended before the mic was live
- **WHEN** the Talk button reports a hold that ended by `pointerup` after 60 ms with no mic open time
- **THEN** the server logs "hold ended by pointerup after 60 ms, lost capture: false, mic open: none"

#### Scenario: Bad hold end report ignored
- **WHEN** the Talk button reports a hold with an unknown ending or a length that is not a non-negative integer
- **THEN** nothing is logged and the screen is unchanged

#### Scenario: Server moment does not drive the button
- **WHEN** the Talk button reports the moment `recording`
- **THEN** `#talk-screen` has `data-state="recording"` and the server renders `#talk-button` only with its static `data-state="idle"`, which the Talk hook replaces with its own

### Requirement: Mic only while held
The Talk button SHALL open a fresh mic on each press and SHALL enter `recording` only once the mic stream is live, counting samples from then. When the hold ends, by release or cancel, it SHALL stop every mic track and disconnect its capture nodes, so the phone's mic indicator goes off; the playback audio context stays. A hold that ends before the mic is live SHALL send no Question.

#### Scenario: Mic off after each hold
- **WHEN** a Guest holds the Talk button, speaks and lets go
- **THEN** one Question is sent and the phone's mic indicator turns off within a second
- **AND** the next press opens the mic again

## MODIFIED Requirements

### Requirement: Moment visuals and status
The card SHALL shrink to a slim strip while `uploading` and `waiting`, and be full while `idle`, `recording` and `speaking`, so nothing moves under a held finger. The ring on Maya's ball SHALL pulse coral while `recording`, spin gold while `uploading` or `waiting`, and glow green with a sound wave while `speaking`; under reduced motion none of them animate. A status line with id `talk-status` SHALL be an aria-live region reading the moment as text.

#### Scenario: Status per moment
- **WHEN** `#talk-screen` is `idle`, `recording`, `waiting` and `speaking` in turn
- **THEN** `#talk-status` (with `role="status"`) reads "Ready when you are", "Listening to you…", "Thinking…" and "Maya is speaking"

#### Scenario: Wave only while speaking
- **WHEN** `#talk-screen` is `speaking`
- **THEN** `#talk-status` contains a `.wave` hidden from screen readers
