# 009: Realtime transcription

- Status: Accepted
- Date: 2026-11-15 (accepted by Abhishek, #75: fast track, Premier tier and `mint_web_socket` approved)

## Context
Batch STT starts only after the whole clip is uploaded, so the Guest sees nothing while talking and every STT millisecond sits between release and Answer. Abhishek reports many transcription errors. Voxtral realtime (`voxtral-mini-transcribe-realtime-3`, Public Preview, Premier tier) streams text while audio arrives over a WebSocket; Mistral publishes no WER for it and recommends file transcription for recorded audio ([transcribe in realtime](https://docs.mistral.ai/studio/audio/speech-to-text/transcribe-in-realtime)). Req, our only HTTP client, has no WebSocket support.

## Decision
- **Hook to server: a stream, not an upload.** While held, the TalkHook sends `stream_start`, 200 ms chunks of 16 kHz mono `pcm_s16le` as base64 `audio_chunk` events (the warm-mic pre-roll first), and `stream_end` after the 150 ms post-roll. One hold is one Question. The Conversation validates each chunk (base64, at most 16 KB decoded, at most 1 MB per Question) and buffers it. The LiveView upload is gone. This supersedes ADR-005's "In" bullet; its "Out" bullet stands.
- **Server to Mistral: one WebSocket per hold.** `Maya.Voice.Realtime` is a process under `Maya.TaskSupervisor` that owns a process-less `Mint.WebSocket` connection ([hexdocs 1.0.6](https://hexdocs.pm/mint_web_socket/1.0.6/Mint.WebSocket.html)) to `wss://api.mistral.ai/v1/audio/transcriptions/realtime?model=...` with the same `MISTRAL_API_KEY`. After `session.created` it sends `session.update` (`pcm_s16le` 16000 Hz, `language: en`, the same up to 400 `context_bias` names as batch, `target_streaming_delay_ms` 480), then the queued audio. Deltas become `#live-question` on the Talk screen; partial text never reaches the agent. The browser never talks to Mistral, so the CSP is unchanged.
- **Client: `mint_web_socket` 1.0.6** (2026-08-12), pinned exactly. It only adds itself on top of Mint 1.11, already in the lock through Finch. Not `websockex`: its own process model and socket stack, and a maintenance gap (design.md).
- **Final transcript: batch until the eval says otherwise.** `:stt_final` is `:batch`: on release the buffered audio is wrapped in a WAV header and sent to batch STT, and realtime is the live preview only. It becomes `:realtime` only if `mix maya.stt_eval` shows realtime's WER at most and name accuracy at least batch's on the 20 Question set. `Vocabulary.correct` runs on both paths.
- **Fallback.** A refused connection, an `error` event, a close or no `transcription.done` within 1500 ms of release sends the buffer to batch STT, with `stt_realtime failed: <reason>` logged (never audio or text). `turns.stt_source` records `realtime` or `batch`; `stt_ms` is release to final transcript.
- **Off by default.** `MAYA_STT_REALTIME=true` (Render env) turns on the relay and the preview. Unset means batch only, as before this ADR, but still over the stream.

## Eval numbers
Not run yet: the key lives only in Render and Abhishek's `.env`. To fill in from `mix maya.stt_eval spike`, `mix maya.stt_eval fixtures --voices ...` and `mix maya.stt_eval [--delay 480|1200]`:

| Source | Delay | WER | Name accuracy | `input_audio.end` to `transcription.done` |
|---|---|---|---|---|
| Batch | n/a | tbd | tbd | n/a |
| Realtime | 480 ms | tbd | tbd | tbd |

The 20 clips are Voxtral TTS voices with light noise, not phone recordings (Abhishek, #75), so both numbers are optimistic next to a real voice in a room. A phone-recorded set can follow.

## Cost
Realtime $0.008 per minute, batch $0.0035 per minute ([realtime model](https://docs.mistral.ai/models/voxtral-mini-transcribe-realtime-3-0), [batch model](https://docs.mistral.ai/models/voxtral-mini-transcribe-3-0)), billed on streamed audio.

| | Batch only | Realtime preview, batch final | Realtime final |
|---|---|---|---|
| One 5 s Question | $0.00029 | $0.00096 | $0.00067 |
| One hour of held audio | $0.21 | $0.69 | $0.48 |

Guests need no login (#49 deferred), so realtime spend scales with visitors; Sentry (#87) and the E3 probe make it visible.

## Consequences
- Easier: live words while held; `stt_ms` can drop to the realtime tail once `:stt_final` is `:realtime`; batch stays the safety net on the same audio.
- Harder: about five small events a second through TalkLive and the Conversation while held; one more dependency; pings and close frames are ours to handle; a Public Preview model id that may change (it is config).
- Check: the spike and eval with the real key before turning `MAYA_STT_REALTIME` on; per-stage p50 and p95 before and after (`mix maya.latency`); Render CPU during the phone run.
