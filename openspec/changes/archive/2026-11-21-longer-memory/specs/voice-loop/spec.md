## MODIFIED Requirements

### Requirement: Spoken Answer
Maya SHALL turn one held Question into an Answer: the streamed audio is transcribed, the final transcript is the Question, and the agent answers it given the last 25 turns. The Answer SHALL be spoken by Voxtral TTS streamed as PCM and relayed to the browser as it arrives. Only text is kept, never the Question audio. STT, the agent and TTS SHALL be called only from the server.

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
