## MODIFIED Requirements

### Requirement: One Conversation that survives crashes
Maya SHALL run one Conversation process per guest, started on demand and found by the guest id. Each finished turn SHALL be stored in Postgres with its guest id, Question text, Answer text and cut flag. When a Conversation process crashes it SHALL be restarted and SHALL reload that guest's recent turns from Postgres.

#### Scenario: Crash reload
- **WHEN** a turn has been stored and the Conversation process is killed
- **THEN** a new Conversation process is running under the same guest id
- **AND** its turns include the stored turn

#### Scenario: Latency unchanged
- **WHEN** a turn completes
- **THEN** it still stores `stt_ms`, `agent_ms` and `tts_first_byte_ms`, and the only added work on the path to first sound is one indexed Progress read by guest id

## ADDED Requirements

### Requirement: Idle Conversation stops
A Conversation with no message for 30 minutes SHALL stop normally and SHALL NOT be restarted; the guest's next visit or Question SHALL start it again with the turns reloaded from Postgres.

#### Scenario: Idle stop and reload
- **WHEN** a guest's Conversation has a stored turn and gets no message for the idle time
- **THEN** the process exits normally and is not restarted
- **AND** the next start for that guest reloads the stored turn
