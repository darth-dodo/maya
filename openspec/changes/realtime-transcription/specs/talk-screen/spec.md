# Spec Delta

## MODIFIED Requirements

### Requirement: Talk button state machine
The Talk button SHALL run as an explicit state machine with the states `idle`, `recording`, `uploading`, `waiting` and `speaking`, shown in its `data-state` attribute. Pressing and holding starts a stream: the button sends 16 kHz mono 16-bit PCM chunks of 100 to 250 ms while held, then an end of stream on release, so one hold makes exactly one Question. Pressing while `speaking` is a barge-in that stops audio at once and starts a new stream. The button SHALL report the mic release and playback start timings back to the server.

#### Scenario: Idle on load
- **WHEN** a visitor opens `/`
- **THEN** `#talk-button` has `data-state="idle"` and is bound to the Talk hook

#### Scenario: One upload per hold
- **WHEN** the button sends a stream start, 8 chunks and a stream end
- **THEN** the Conversation receives exactly one Question and no file upload is made
- **AND** a second stream end for the same hold is ignored

#### Scenario: Chunk size
- **WHEN** a 2 second hold is streamed
- **THEN** every chunk but the last holds 1600 to 4000 samples (100 to 250 ms at 16 kHz)

## ADDED Requirements

### Requirement: Live transcript bubble
While a hold streams, the Talk screen SHALL show the partial transcript in a Guest bubble `#live-question`, updated as text arrives, and SHALL replace it with the pending Question when the final transcript is ready. The bubble SHALL be in the conversation's polite live region.

#### Scenario: Live words while held
- **WHEN** the Conversation reports the partial text "where do I catch"
- **THEN** `#live-question` contains "where do I catch"

#### Scenario: Live bubble replaced on final
- **WHEN** the final transcript "where do I catch Ralts?" is ready
- **THEN** `#live-question` is gone and `#pending-question` contains "where do I catch Ralts?"
