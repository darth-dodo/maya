# Spec Delta

## MODIFIED Requirements

### Requirement: Spoken Answer
Maya SHALL turn one held Question into an Answer: the audio streamed during the hold is transcribed (realtime STT with batch fallback), the final transcript is the Question text, and the Answer text comes from the agent given the last 5 turns and the Question. The Answer SHALL be spoken by Voxtral TTS streamed as PCM and relayed to the browser as it arrives. The Question audio SHALL be dropped once the final transcript exists; only text is kept. STT, the agent and TTS SHALL be called only from the server; the browser SHALL never connect to Mistral.

#### Scenario: Question is transcribed and answered by the agent
- **WHEN** a Question is streamed, STT returns "How do I earn Roxanne's badge?" and the agent answers "Lead with Mudkip against Nosepass. Mudkip would approve."
- **THEN** the Conversation has a turn with that Question and that Answer
- **AND** TTS is asked to speak the Answer with `stream: true` and `response_format: pcm`
- **AND** every `speech.audio.delta` chunk is relayed to the screen in order, followed by an end-of-audio signal

#### Scenario: Stream events split across network chunks
- **WHEN** TTS events arrive split at arbitrary byte boundaries
- **THEN** each `speech.audio.delta` is decoded exactly once and in order
- **AND** `speech.audio.done` ends the stream

#### Scenario: Nothing heard
- **WHEN** STT returns an empty transcript
- **THEN** the Answer is "I did not catch that." and it is spoken, without calling the agent

### Requirement: STT is biased toward known names
Every STT request, batch or realtime, SHALL carry the documented `context_bias` terms: one form field per term for batch, one array in the realtime session settings, sent before the first audio. The terms SHALL come from Maya's game data and the Guest's Progress: "Maya", "Mudkip", the Team, the Next gym leader, locations inside the Spoiler horizon, then every other known species, gym leader, gym city and location. Terms SHALL be unique and SHALL be capped at 400. The realtime session SHALL also set `language` to `en`.

#### Scenario: Bias terms in the request
- **WHEN** a Guest with Mudkip on the Team and no badges asks a Question
- **THEN** the STT request has one `context_bias` field each for "Maya", "Mudkip", "Roxanne", "Rustboro City", "Ralts" and "Torchic"
- **AND** no term repeats, there are at most 400 terms and their total size is under 8 KB

#### Scenario: Realtime session settings
- **WHEN** a realtime session starts for a Guest with Mudkip on the Team and no badges
- **THEN** its settings message, sent before any audio, has `audio_format` `pcm_s16le` at 16000 Hz, `language` `en` and a `context_bias` array that starts with "Maya", "Mudkip" and "Roxanne"

#### Scenario: Priority order when capped
- **WHEN** the terms are capped below the full list
- **THEN** "Maya", "Mudkip", the Team, the Next gym leader and the horizon locations come first and the rest is cut from the end

## ADDED Requirements

### Requirement: Streamed Question audio
While a hold is active the Conversation SHALL accept audio chunks of 16 kHz mono 16-bit PCM, relay each to the realtime STT session in order and keep them for a batch fallback. A chunk that is not valid base64, is over 16 KB decoded, or would take the Question past 1 MB SHALL be dropped and logged. A new hold or a barge-in SHALL close the previous session.

#### Scenario: Chunks relayed in order
- **WHEN** the screen sends 10 chunks of 200 ms for one hold
- **THEN** the realtime session receives 10 audio messages in the same order, then an end of audio on release

#### Scenario: Oversized chunk dropped
- **WHEN** a chunk decodes to 20 KB
- **THEN** it is not relayed, a warning with its size and no audio is logged, and the hold goes on

### Requirement: Live partial transcript
Text deltas from the realtime session SHALL be shown to the Guest as they arrive, appended in order. Partial text SHALL NOT reach the agent; only the final transcript does.

#### Scenario: Partial text shown
- **WHEN** the realtime session sends the deltas "where do", " I catch" and " Ralts"
- **THEN** the screen shows "where do I catch Ralts" in the live bubble while the hold is active
- **AND** the agent is not called before release

### Requirement: Realtime falls back to batch
When the realtime session fails to connect, sends an error, closes, or has no final transcript within a set time after release (default 1500 ms), the Conversation SHALL transcribe the buffered audio with batch STT and SHALL log the failure reason (an atom, status or error code, never audio or text). The Guest SHALL still get an Answer. When batch also fails, the existing "voice is down" path applies.

#### Scenario: Connection refused
- **WHEN** the realtime connection is refused and batch returns "where do I catch Ralts?"
- **THEN** the Question is "where do I catch Ralts?", the turn's `stt_source` is `batch`, and a warning "stt_realtime failed: ..." is logged

#### Scenario: No final in time
- **WHEN** the realtime session sends no `transcription.done` within 1500 ms of release
- **THEN** the session is closed, batch STT transcribes the buffered audio and the reason `:done_timeout` is logged

### Requirement: Accuracy gate for the final transcript
The final transcript SHALL come from realtime only when, on the fixed 20 Question test set, realtime's word error rate is at most batch's and its name accuracy is at least batch's. Otherwise batch SHALL give the final transcript from the streamed audio and realtime SHALL give only the live preview. The choice SHALL be a config value set from the recorded numbers.

#### Scenario: Batch kept when realtime is worse
- **WHEN** the final source is configured as batch and a hold streams audio
- **THEN** the live bubble shows realtime deltas, the final transcript comes from batch STT on the streamed audio, and the turn's `stt_source` is `batch`

### Requirement: Accuracy measures
Word error rate SHALL be the word-level edit distance over the reference word count, after lowercasing and removing punctuation. Name accuracy SHALL be the share of expected names that appear exactly in the corrected transcript.

#### Scenario: Word error rate
- **WHEN** the reference is "Where do I catch Ralts?" with the expected name "Ralts", and the corrected transcript is "where do I catch rails"
- **THEN** the word error rate is 0.2 and the name accuracy is 0.0

### Requirement: Realtime latency
Each turn SHALL store `stt_source` (`realtime` or `batch`). `stt_ms` SHALL be the time from the server receiving the end of the hold to the final transcript. The PR SHALL show per-stage p50 and p95 before and after.

#### Scenario: STT stage drops with realtime
- **WHEN** 10 phone holds are measured before (batch) and after (realtime final)
- **THEN** the PR shows `mic_release_ms`, `stt_ms`, `confirm_ms`, `agent_ms`, `tts_first_byte_ms` and `playback_start_ms` p50 and p95 for both, `stt_ms` p50 is lower after, and no other stage is more than 100 ms slower
