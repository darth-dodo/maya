# Design

Block 2 of ARCHITECTURE.md ("1 The voice loop", "2 Processes", "4 Data"), ADR-005 and ADR-006. Echo only: the transcript is the Answer until the agent lands (#39).

## Format spike (ADR-005)

Mistral documents no input containers for file transcription ([audio formats](https://docs.mistral.ai/studio/audio/specs-and-limits/audio-formats)). The builder session had no `MISTRAL_API_KEY`, so the spike is a script for Abhishek: `scripts/voice_spike.sh` (`DRY_RUN=1` makes the clips and prints the calls). It speaks "How do I earn the first badge" with macOS `say`, converts it to the three formats, posts each to `POST /v1/audio/transcriptions` with `voxtral-mini-transcribe-3` ([transcribe files](https://docs.mistral.ai/studio/audio/speech-to-text/transcribe-files)), then asks TTS for a `pcm` stream and a `wav` file, whose header names the PCM rate, bit depth and int or float.

| Probe | Result | Source |
|---|---|---|
| WAV 16 kHz mono 16-bit to STT | Not run (no key in the builder session) | `scripts/voice_spike.sh` |
| MP4/AAC (iOS MediaRecorder) to STT | Not run | same |
| WebM/Opus (Chrome MediaRecorder) to STT | Not run | same |
| TTS PCM sample rate | 24 kHz mono, documented: "Generated speech is mono at 24 kHz." | [audio formats](https://docs.mistral.ai/studio/audio/specs-and-limits/audio-formats) |
| TTS PCM sample type | Not documented; assumed signed 16-bit little-endian (the realtime input format). The spike's WAV header confirms or refutes it | same |
| TTS stream events | `speech.audio.delta` with base64 `audio_data`, then `speech.audio.done` with `usage` | [stream speech](https://docs.mistral.ai/studio/audio/text-to-speech/stream-speech) |

Decision until the spike runs: the hook records **16 kHz mono 16-bit WAV** with Web Audio and encodes it in JS. A WAV header needs no container support, so it is the safe default ADR-005 names. If the spike shows MP4 and WebM both work, a later change can switch to MediaRecorder (smaller uploads); if the TTS WAV header says float, the hook's PCM decode (one function) changes to Float32.

Note: the iOS and Chrome rows above mean clips made on this Mac in the same containers, not recordings from the devices. A real phone check is in the PR's "only Abhishek can verify" list.

## Processes

```
Maya.Supervisor
  Registry Maya.ConversationRegistry
  DynamicSupervisor Maya.ConversationSupervisor -> Maya.Conversation ("main")
  Task.Supervisor Maya.TaskSupervisor
```

- `Maya.Conversation.ensure_started/1` starts the one Conversation on demand (`{:via, Registry, ...}`), restart `:permanent` under the DynamicSupervisor so a crash restarts it; `init/1` reloads recent turns from Postgres.
- A turn: `{:question, audio}` starts an STT Task (`Task.Supervisor.async_nolink`, monitored). Its result becomes the Answer (echo) and starts a TTS Task that sends `{:tts_chunk, turn_ref, pcm}` to the Conversation, which broadcasts on PubSub `conversation:<id>`. A new Question while a turn is in flight cuts the old one.
- Barge-in kills the TTS Task, marks the turn cut, keeps its Answer text. Late chunks carry the old turn ref and are dropped.
- TalkLive only renders: it reads turns (Postgres on the dead render, the Conversation when connected), subscribes, and pushes `audio` events to the hook.

## Pure core

- `Maya.Voice.SSE.parse(buffer)` returns `{events, rest}`; partial events stay in `rest` for the next chunk.
- `Maya.Voice.Latency.summary(rows)` returns p50 and p95 per stage (nearest rank).
- The JS hook keeps WAV encoding and downsampling as plain functions.

## Timing

| Stage (column) | Measured | How |
|---|---|---|
| `mic_release_ms` | mic release to the server having the clip | Hook: release to the `heard` event |
| `stt_ms` | the STT call | `:telemetry.span([:maya, :voice, :stt], ...)` |
| `tts_first_byte_ms` | TTS request to first PCM chunk | `[:maya, :voice, :tts_first_byte, :stop]` event |
| `playback_start_ms` | mic release to first sound (Answer time) | Hook: release to the first scheduled buffer |

`Maya.Voice.Timing` handles `[:maya, :voice, stage, :stop]` and sends the milliseconds to the Conversation, which keeps them on the in-flight turn. The row is written when the TTS stream ends (done, cut or error), after the Answer started playing (ADR-006); the client's playback numbers update it when they arrive. The agent stage column comes with #39.

## Config

`config :maya, :voice` holds `stt_model`, `tts_model`, `tts_voice`, `tts_sample_rate` (24000), `stt_timeout_ms`, `tts_timeout_ms`. `config :maya, :mistral` holds `api_key` (from `MISTRAL_API_KEY`, `config/runtime.exs` only) and `req_options` (tests: `plug: {Req.Test, Maya.Mistral}`). A missing key is a voice outage, not a boot failure, so the app degrades to text.

## Risks

- PCM sample type unconfirmed (see the spike table).
- `ScriptProcessorNode` is deprecated but works on iOS Safari and Chrome and needs no extra module file; an AudioWorklet is the upgrade if it glitches.
- The first hold triggers the mic permission prompt; that hold may record nothing.
