## ADDED Requirements

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

## REMOVED Requirements

### Requirement: Spoken echo
**Reason**: The agent answers the Question now (#39).
**Migration**: See "Spoken Answer".

## MODIFIED Requirements

### Requirement: Per-stage latency
Each stored turn SHALL hold milliseconds for the stages mic release (release to the server having the clip), STT, agent, TTS first byte, and playback start (release to first sound, the Answer time). `mix maya.latency` SHALL print p50 and p95 per stage over the stored turns. The turn row SHALL be written after the Answer starts streaming, never before TTS starts.

#### Scenario: Stage timings are stored
- **WHEN** a turn completes and the screen reports mic release 180 ms and playback start 2400 ms
- **THEN** the stored turn has `mic_release_ms` 180, `playback_start_ms` 2400, and non-negative `stt_ms`, `agent_ms` and `tts_first_byte_ms`

#### Scenario: Latency report
- **WHEN** the stored turns have `stt_ms` values 100, 200, 300, 400 and 500
- **THEN** `mix maya.latency` prints for `stt_ms` a p50 of 300 and a p95 of 500
- **AND** stages with no values print as missing, not zero
