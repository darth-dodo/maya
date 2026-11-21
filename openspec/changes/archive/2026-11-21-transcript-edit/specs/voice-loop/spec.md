# Spec Delta

## ADDED Requirements

### Requirement: Countdown overlaps the agent
After STT returns a non-empty, corrected transcript, the Conversation SHALL call the agent at once and run a countdown (default 2000 ms; 0 shows none) in parallel. During the countdown an edit or a new Question SHALL discard the in-flight Answer: never spoken, never stored. An edited Question SHALL go to the agent as a new one; a cancel stores no turn. An empty transcript SHALL speak "I did not catch that." as today.

#### Scenario: Untouched Question has no added wait
- **WHEN** STT returns "where do I catch Ralts?" with a 2000 ms countdown and nothing is tapped
- **THEN** the agent is asked "where do I catch Ralts?" before the countdown ends
- **AND** the stored turn has `confirm_ms` under 100

#### Scenario: Edit discards the in-flight Answer
- **WHEN** STT returns "where do I catch rawls", the Guest opens it to edit during the countdown and sends "where do I catch Ralts?"
- **THEN** the first agent call is stopped, its Answer is never spoken or stored
- **AND** the agent is asked "where do I catch Ralts?" and the one stored turn has that Question

#### Scenario: A write of the discarded run stays
- **WHEN** the discarded run already logged an Event (a catch, a level) before the tap
- **THEN** that Event stays, as with a barge-in during the agent stage, and the screen gets the new Progress so the card redraws

#### Scenario: Cancelled Question is not stored
- **WHEN** a Question opened to edit is cancelled
- **THEN** no Answer is spoken and the Guest's stored turns are unchanged

#### Scenario: New Question discards the pending one
- **WHEN** a Question is in its countdown and a new hold starts
- **THEN** the first Question's Answer is never spoken or stored

### Requirement: Typed Question
A typed Question SHALL go to the agent with the Guest's Progress and last 5 turns, as a spoken Question does, without calling STT and without a countdown. Its turn SHALL be stored with `typed` true and blank `mic_release_ms`, `stt_ms` and `confirm_ms`. Typed and edited text SHALL reach the agent as written, trimmed, and SHALL be 1 to 300 characters.

#### Scenario: Typed turn stored
- **WHEN** the Guest types "where do I catch Ralts?" and the Answer finishes
- **THEN** the stored turn has that Question, `typed` true, and `stt_ms`, `mic_release_ms` and `confirm_ms` blank
- **AND** STT was not called

### Requirement: Countdown latency stage
Each spoken turn SHALL store `confirm_ms`: milliseconds from STT done to the agent call that gave its Answer, near 0 when untouched and the edit time when edited. `mix maya.latency` SHALL print `confirm_ms` as its own stage. `playback_start_ms` (the Answer time) SHALL stay measured from release, any edit included; for a typed turn it is measured from Send.

#### Scenario: Countdown stage stored
- **WHEN** a spoken turn is edited for about 400 ms and then sent
- **THEN** the stored turn has `confirm_ms` of at least 400
- **AND** `mix maya.latency` prints a `confirm_ms` line
