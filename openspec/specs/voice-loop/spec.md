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

#### Scenario: STT is down
- **WHEN** STT returns an error
- **THEN** the screen shows the note "voice is down"
- **AND** the Talk button returns to idle

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
Maya SHALL turn one uploaded Question clip into an Answer: the clip is sent to Voxtral STT, the transcript is the Question text, and the Answer text comes from the agent given the last 5 turns and the Question. The Answer SHALL be spoken by Voxtral TTS streamed as PCM and relayed to the browser as it arrives. The clip SHALL be dropped after STT; only text is kept. STT, the agent and TTS SHALL be called only from the server.

#### Scenario: Question is transcribed and answered by the agent
- **WHEN** a Question clip is sent, STT returns "How do I earn Roxanne's badge?" and the agent answers "Lead with Mudkip against Nosepass. Mudkip would approve."
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
Every STT request SHALL carry the documented `context_bias` field, one form field per term. The terms SHALL come from Maya's game data and the Guest's Progress: "Maya", "Mudkip", the Team, the Next gym leader, locations inside the Spoiler horizon, then every other known species, gym leader, gym city and location. Terms SHALL be unique and SHALL be capped at 400.

#### Scenario: Bias terms in the request
- **WHEN** a Guest with Mudkip on the Team and no badges asks a Question
- **THEN** the STT request has one `context_bias` field each for "Maya", "Mudkip", "Roxanne", "Rustboro City", "Ralts" and "Torchic"
- **AND** no term repeats, there are at most 400 terms and their total size is under 8 KB

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
