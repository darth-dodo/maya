# Spec Delta

## ADDED Requirements

### Requirement: Countdown before the agent
After STT returns a non-empty, corrected transcript, the Conversation SHALL wait a configured countdown (default 2000 ms; 0 sends at once) before calling the agent. During the countdown or an edit the Question SHALL be pending: an edit stops the countdown, a send uses the edited text, a cancel or a new Question discards it with no agent call and no stored turn. An empty transcript SHALL skip the countdown and speak "I did not catch that." as today.

#### Scenario: Untouched Question is sent after the countdown
- **WHEN** STT returns "where do I catch Ralts?" and nothing happens for 2000 ms
- **THEN** the agent is asked "where do I catch Ralts?" no earlier than 2000 ms after STT finished

#### Scenario: Cancelled Question is not stored
- **WHEN** a pending Question is cancelled
- **THEN** the agent is not called and the Guest's stored turns are unchanged

#### Scenario: New Question discards the pending one
- **WHEN** a Question is pending and a new Question clip arrives
- **THEN** the pending Question is never sent to the agent

### Requirement: Typed Question
A typed Question SHALL go to the agent with the Guest's Progress and last 5 turns, as a spoken Question does, without calling STT and without a countdown. Its turn SHALL be stored with `typed` true and blank `mic_release_ms`, `stt_ms` and `confirm_ms`. Typed and edited text SHALL reach the agent as written, trimmed, and SHALL be 1 to 300 characters.

#### Scenario: Typed turn stored
- **WHEN** the Guest types "where do I catch Ralts?" and the Answer finishes
- **THEN** the stored turn has that Question, `typed` true, and `stt_ms`, `mic_release_ms` and `confirm_ms` blank
- **AND** STT was not called

### Requirement: Countdown latency stage
Each spoken turn SHALL store `confirm_ms`: milliseconds from STT done to the agent call, covering the countdown and any edit. `mix maya.latency` SHALL print `confirm_ms` as its own stage. `playback_start_ms` (the Answer time) SHALL stay measured from release, countdown included; for a typed turn it is measured from Send.

#### Scenario: Countdown stage stored
- **WHEN** a spoken turn completes untouched with a 2000 ms countdown
- **THEN** the stored turn has `confirm_ms` of at least 2000 and under 2200, and non-negative `stt_ms`, `agent_ms` and `tts_first_byte_ms`
- **AND** `mix maya.latency` prints a `confirm_ms` line with its p50 and p95
