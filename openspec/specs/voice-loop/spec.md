# voice-loop Specification

## Purpose
The push-to-talk loop on the server: a Question clip becomes text, the agent answers it, the Answer is spoken as streamed PCM, barge-in cuts it, a voice outage degrades to text, and every stage is timed per turn.

## Requirements

### Requirement: One Conversation that survives crashes
Maya SHALL run one Conversation process per guest, started on demand and found by the guest id. Each finished turn SHALL be stored in Postgres with its guest id, Question text, Answer text and cut flag. When a Conversation process crashes it SHALL be restarted and SHALL reload that guest's recent turns from Postgres.

#### Scenario: Crash reload
- **WHEN** a turn has been stored and the Conversation process is killed
- **THEN** a new Conversation process is running under the same guest id
- **AND** its turns include the stored turn

#### Scenario: Latency unchanged
- **WHEN** a turn completes
- **THEN** it still stores `stt_ms`, `agent_ms` and `tts_first_byte_ms`, and the only added work on the path to first sound is one indexed Progress read by guest id

### Requirement: Idle Conversation stops
A Conversation with no message for 30 minutes SHALL stop normally and SHALL NOT be restarted; the guest's next visit or Question SHALL start it again with the turns reloaded from Postgres.

#### Scenario: Idle stop and reload
- **WHEN** a guest's Conversation has a stored turn and gets no message for the idle time
- **THEN** the process exits normally and is not restarted
- **AND** the next start for that guest reloads the stored turn

### Requirement: Barge-in
A new hold while Maya speaks SHALL stop the TTS stream for that turn. The cut Answer SHALL stay as text, be marked cut, and no further audio from that turn SHALL reach the screen.

#### Scenario: Barge-in cuts the Answer
- **WHEN** TTS is streaming an Answer and the player barges in
- **THEN** the TTS stream for that turn is cancelled
- **AND** the turn is stored with its Answer text and the cut flag set
- **AND** no audio chunk from that turn is relayed after the barge-in

### Requirement: Voice outage degrades to text
When STT or TTS errors or times out, Maya SHALL show the Answer as text with a "voice is down" note and SHALL NOT fall back to browser speech.

#### Scenario: TTS is down
- **WHEN** STT succeeds and TTS returns an error
- **THEN** the turn shows its Answer text with the note "voice is down"
- **AND** the turn is stored
- **AND** the log names the status and the first 500 bytes of the provider's error body, with the Answer text replaced by "[input]"

#### Scenario: TTS fails mid-stream
- **WHEN** TTS fails after some Answer chunks were relayed
- **THEN** the screen gets "voice is down", never silence with no end, and the turn is stored with the voice down flag

#### Scenario: TTS sample rate pinned
- **WHEN** the configured TTS output is checked
- **THEN** it is `pcm` streamed at 24 kHz, as the Voxtral docs give for generated speech

#### Scenario: STT is down
- **WHEN** STT returns an error
- **THEN** the screen shows the note "voice is down"
- **AND** the Talk button returns to idle

### Requirement: Database outage is not a voice outage
When Postgres fails during a turn, Maya SHALL name the real problem and SHALL NOT show "voice is down" or crash. If Progress cannot be read, the spoken Answer SHALL be "I can't reach my notes right now, ask again soon?" without calling the agent. If storing the turn or its timings fails, the turn SHALL stay on screen. Each failure SHALL be logged with its kind, never a query message.

#### Scenario: Progress cannot be read
- **WHEN** a Question is uploaded or held and the Progress read fails
- **THEN** STT still runs and the Question shows
- **AND** "I can't reach my notes right now, ask again soon?" is spoken, the agent is not called and no "voice is down" note shows
- **AND** the log says `progress failed` with the error kind

#### Scenario: Storing the turn fails
- **WHEN** the Answer has streamed and storing the turn fails
- **THEN** the turn stays on screen with its Answer, no "voice is down" note shows and the log says `store failed`

#### Scenario: Storing the timings fails
- **WHEN** a stored turn's playback timings arrive and the update fails
- **THEN** the turn keeps the timings in memory and the Conversation keeps running

#### Scenario: Conversation starts while Postgres is down
- **WHEN** a Conversation starts and its recent turns cannot be read
- **THEN** it starts with no turns instead of crashing

### Requirement: Per-stage latency
Each stored turn SHALL hold milliseconds for the stages mic release (release to the server having the clip), STT, agent, TTS first byte, and playback start (release to first sound, the Answer time). `mix maya.latency` SHALL print p50 and p95 per stage over the stored turns. The turn row SHALL be written after the Answer starts streaming, never before TTS starts.

#### Scenario: Stage timings are stored
- **WHEN** a turn completes and the screen reports mic release 180 ms and playback start 2400 ms
- **THEN** the stored turn has `mic_release_ms` 180, `playback_start_ms` 2400, and non-negative `stt_ms`, `agent_ms` and `tts_first_byte_ms`

#### Scenario: Latency report
- **WHEN** the stored turns have `stt_ms` values 100, 200, 300, 400 and 500
- **THEN** `mix maya.latency` prints for `stt_ms` a p50 of 300 and a p95 of 500
- **AND** stages with no values print as missing, not zero

### Requirement: Spoken Answer
Maya SHALL turn one held Question into an Answer: the streamed audio is transcribed, the final transcript is the Question, and the agent answers it given the last 5 turns. The Answer SHALL be spoken by Voxtral TTS streamed as PCM and relayed to the browser as it arrives. Only text is kept, never the Question audio. STT, the agent and TTS SHALL be called only from the server.

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

### Requirement: Agent failure is spoken
When the agent fails, the Answer SHALL be the one spoken line "Lost my train of thought, ask again?", never silence.

#### Scenario: Agent is down
- **WHEN** STT succeeds and OpenRouter returns an error
- **THEN** the Answer "Lost my train of thought, ask again?" is spoken and stored

### Requirement: STT is biased toward known names
Every STT request, batch or realtime, SHALL carry the `context_bias` terms (realtime: in the session settings, before any audio). The terms SHALL be, in order: "Maya", "Mudkip", the Team, the Next gym leader, locations inside the Spoiler horizon, then every other known species, gym leader, gym city and location. Terms SHALL be unique and capped at 400.

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

### Requirement: Bias terms only steer recognition
Bias terms SHALL NOT be shown to the player and SHALL NOT be sent to the agent's model as Facts; only the player's own transcript reaches the agent.

#### Scenario: No past-horizon name reaches the model from the bias
- **WHEN** a Guest with no badges asks "hello"
- **THEN** the agent's request contains no bias term the player did not say, such as "Sootopolis City"

### Requirement: Transcript names are corrected before the agent
The transcript SHALL be corrected before the agent sees it: a word, or two adjacent words joined, that is close to a known name by Jaro distance (at least 0.86, same first letter, not a prefix of the name, length within 2) SHALL become that name. A word on the committed list of English words near a name, or shorter than 4 letters, SHALL stay as spoken. A possessive and punctuation SHALL be kept. The shown and stored Question SHALL be the corrected text.

#### Scenario: Real misses are corrected
- **WHEN** the transcript is "where do I catch rawls", "what is torch ick weak to", "is zigzag goon on route 101" or "how do I earn roxane's badge?"
- **THEN** the Question becomes "where do I catch Ralts", "what is Torchic weak to", "is Zigzagoon on route 101" or "how do I earn Roxanne's badge?"

#### Scenario: English words are kept
- **WHEN** the transcript contains "rocks", "beach", "where", "badge", "route", "rails", "golden", "which", "electric" or "around"
- **THEN** each of those words is unchanged

#### Scenario: The corrected Question is stored
- **WHEN** STT returns "where do I catch rawls?"
- **THEN** the agent is asked "where do I catch Ralts?" and the stored turn has that Question

### Requirement: STT stage latency with bias
The Progress read SHALL move into the STT stage and be reused by the agent, so a turn still reads Progress once. `stt_ms` SHALL include building the terms and the correction.

#### Scenario: One Progress read per turn
- **WHEN** a turn completes
- **THEN** it stores non-negative `stt_ms`, `agent_ms` and `tts_first_byte_ms`
- **AND** the Guest's Progress was read once for the turn

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
