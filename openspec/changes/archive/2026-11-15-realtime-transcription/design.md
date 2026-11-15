# Design

## Context

See proposal.md, Why. After `warm-mic` the hook keeps a live mic with a pre-roll for the turn; after `transcript-edit` the Conversation has a `:confirm` stage between STT and the agent. Today audio reaches the server only as one WAV upload on release (`allow_upload(:question, ...)`, ADR-005), `Maya.Voice.STT` posts it to `POST /v1/audio/transcriptions` with `language` and `context_bias`, and `Vocabulary.correct/2` fixes near-miss names. Req, the only HTTP client, has no WebSocket support.

## Research (Mistral realtime, checked 2026-11-15)

| Fact | Value | Source |
|---|---|---|
| Model | `voxtral-mini-transcribe-realtime-3` in the endpoint (model page id `voxtral-mini-transcribe-realtime-3-0`), v3.0, released 2026-10-20, status Public Preview, tier Premier | [model page](https://docs.mistral.ai/models/voxtral-mini-transcribe-realtime-3-0) |
| Endpoint and auth | `wss://api.mistral.ai/v1/audio/transcriptions/realtime?model=voxtral-mini-transcribe-realtime-3`, `Authorization: Bearer <key>` | [transcribe in realtime](https://docs.mistral.ai/studio/audio/speech-to-text/transcribe-in-realtime) |
| Lifecycle | connect, receive `session.created`, send `session.update`, stream `input_audio.append`, send `input_audio.end` | same |
| Audio format | `audio_format: {encoding, sample_rate}`, default `pcm_s16le` at 16000 Hz | same |
| Audio messages | JSON with base64 audio, not binary frames: `{"type": "input_audio.append", "audio": "<base64>"}` | same |
| Chunk size | No required size; the sample sends 100 ms chunks, paced in real time for latency tests | same |
| Delay | `target_streaming_delay_ms` 80 to 1200 or 2400, default 480; shorter is faster but less accurate | same |
| Language | `language`, ISO 639-1, unset means detect | same |
| Bias | `context_bias`: array of strings in `session.update`, whole session, before the first audio; no documented count limit; entries share the model's context window with the audio | [transcribe in realtime](https://docs.mistral.ai/studio/audio/speech-to-text/transcribe-in-realtime), [bias context and vocabulary](https://docs.mistral.ai/studio/audio/speech-to-text/bias-context-and-vocabulary) |
| Events | `transcription.text.delta` (`text`), `transcription.done` (`text`, `segments`, `language`, `model`, `usage`), `error` (`error.message`, `error.code`) | [transcribe in realtime](https://docs.mistral.ai/studio/audio/speech-to-text/transcribe-in-realtime) |
| Partial vs final | Deltas are append-only and never revise earlier text; each delta is final when received; no interim hypotheses | same |
| Settings | Cannot change after the first audio chunk (error); a new session is needed | same |
| Accuracy | No WER published; for recorded audio the page recommends file transcription; older dual-delay docs run a fast less accurate stream next to a slow more accurate one | same, [realtime (2602, older)](https://docs.mistral.ai/studio/audio/speech_to_text/realtime_transcription) |
| Limits | Session length and rate limits not documented | same pages |
| Price | Realtime $0.008 per minute; batch `voxtral-mini-transcribe-3-0` $0.0035 per minute | [realtime model](https://docs.mistral.ai/models/voxtral-mini-transcribe-realtime-3-0), [batch model](https://docs.mistral.ai/models/voxtral-mini-transcribe-3-0) |
| Browser auth | Short-lived tokens via `POST /v1/client/sessions` exist for browsers; not used here | [client auth](https://docs.mistral.ai/studio/audio/speech_to_text/realtime_transcription/client_auth) |

Availability for Maya's key is not verified in planning (the key lives only in `.env` and Render). Task 1.1 is a spike with the real key, per LESSONS.md (#48). If the key gets a 401, 403 or 404 on the realtime endpoint, the builder stops, reports on #75, and the change waits; `warm-mic` and `transcript-edit` stand alone.

## Goals / Non-Goals

**Goals:** live words while held; final transcript at most a few hundred ms after release; accuracy measured on a fixed set; batch fallback that the Guest never notices beyond a slower Answer.

**Non-Goals:** turn detection, diarization, dual-delay sessions, a browser to Mistral connection, changing TTS.

## Decisions

### WebSocket client: `mint_web_socket` 1.0.6

| | `mint_web_socket` 1.0.6 (2026-08-12) | `websockex` 0.5.1 (2025-12-01) |
|---|---|---|
| Maintenance | `elixir-mint` org, same as Mint; releases 2024, 2025, 2026 | Gap 2021 to 2025; hex now points to a fork, `witchtails/websockex_wt` |
| Deps | Only `mint` (`~> 1.4 and >= 1.4.1`); Mint 1.11.0 is already in `mix.lock` via Finch and Req | `telemetry`; its own `:gen_tcp`/`:ssl` stack, separate from Req/Finch |
| Shape | Process-less, functional; the owning process receives socket messages and calls `stream/2` | A behaviour that runs its own process with callbacks |
| Fit | The relay is one monitored Task under `Maya.TaskSupervisor`; it owns the connection, so cancelling a turn is killing the Task, as for STT, agent and TTS today | A second process per session to link, monitor and stop |

Sources: [hex mint_web_socket](https://hex.pm/packages/mint_web_socket), [Mint.WebSocket docs](https://hexdocs.pm/mint_web_socket/Mint.WebSocket.html) (process-less, `upgrade/5`, `new/5`, `encode/2`, `decode/2`; pings must be answered by the caller), [hex websockex](https://hex.pm/packages/websockex). Pick `mint_web_socket`: one small package on a transport we already ship, and it fits the existing Task model. Cost: we answer pings and handle close frames ourselves (a few lines). Version 1.0.6 is three months old (rule: at least two weeks).

### Transport from hook to server: `pushEvent` with base64

- `pushEvent` payloads are JSON ([JS interop](https://hexdocs.pm/phoenix_live_view/js-interop.html) documents no binary form). A 200 ms chunk of 16 kHz `pcm_s16le` is 6,400 bytes, about 8.5 KB as base64: five small events a second on a socket that already carries base64 PCM the other way.
- Mistral wants base64 inside JSON anyway, so the server validates and forwards the string with no re-encoding, and keeps the decoded bytes for the fallback.
- Alternatives: LiveView uploads (`this.upload`) are file oriented, one entry per upload, and add a round trip per chunk ([uploads](https://hexdocs.pm/phoenix_live_view/uploads.html)); a separate Phoenix Channel can carry `{:binary, data}` payloads ([Phoenix.Channel](https://hexdocs.pm/phoenix/Phoenix.Channel.html)) but adds a socket, a join and auth plumbing for a 33 percent size saving that does not matter at this rate. Rejected for now; revisit if chunk events show up in `mic_release_ms`.

### Flow

1. Press: the hook sends `stream_start`. TalkLive calls `Conversation.stream_start/1`: cut the turn in flight, read Progress once, build bias terms, start the relay Task (connect, `session.update` with `pcm_s16le` 16000, `language: "en"`, `context_bias`, `target_streaming_delay_ms` from config, default 480). Chunks that arrive before `session.updated` queue in the relay.
2. Held: every second ScriptProcessor block (4096 frames at 48 kHz, about 170 ms; first chunk carries the warm-mic pre-roll) is downsampled with the existing `downsample`, converted to int16 and sent as `audio_chunk` with a sequence number. TalkLive validates (base64, at most 16 KB decoded, total at most 1 MB, which matches today's upload cap) and casts to the Conversation, which appends to its buffer and forwards to the relay.
3. Deltas: the relay sends `{:partial, ref, text}`; the Conversation appends and broadcasts `{:partial, text}`; TalkLive renders `#live-question`.
4. Release: `stream_end`, then the relay sends `input_audio.end` and waits for `transcription.done` up to `:stt_realtime_done_ms` (1500). With `stt_final: :realtime` its text is the transcript; with `stt_final: :batch` (or any relay failure) the buffer is wrapped in a 44 byte WAV header and sent to `STT.transcribe/3` as today. Then `Vocabulary.correct/2`, then the `:confirm` stage.
5. `stt_ms` spans `stream_end` to the final transcript; the hook's `heard` mark moves to the `stream_end` acknowledgement, so `mic_release_ms` stays release to server.

### Accuracy evaluation

- **Clips:** `test/fixtures/stt_eval/01.wav` to `20.wav`, 16 kHz mono 16-bit, at most 5 s each (about 160 KB, about 3 MB total), plus `questions.json` with `file`, `text` and `names` per clip. Recorded by Abhishek on the phone he plays on, converted with macOS `afconvert -f WAVE -d LEI16@16000 -c 1 in.m4a 01.wav`.
- **Script:** 1 How do I earn Roxanne's badge? 2 Where do I catch Ralts? 3 Is Zigzagoon on Route 101? 4 What is Torchic weak to? 5 When does Mudkip evolve? 6 What should I lead with against Brawly? 7 How far is Dewford Town? 8 Can I catch Wingull on Route 104? 9 What type is Nosepass? 10 How do I get to Rustboro City? 11 Is Geodude good against Roxanne? 12 Where can I find Shroomish? 13 What level does Marshtomp evolve? 14 What does Wurmple evolve into? 15 Where do I catch Taillow in Petalburg Woods? 16 Who is the gym leader in Dewford Town? 17 Is Lotad a Water type? 18 How do I get from Littleroot Town to Oldale Town? 19 What moves does Makuhita learn? 20 How do I get past Petalburg Woods?
- **Run:** `mix maya.stt_eval [--delay 480]` transcribes every clip with batch and with realtime (paced at 100 ms per 100 ms, as the docs suggest), both with the bias terms of the seed Progress and `Vocabulary.correct`, and prints per clip and total WER and name accuracy. It needs the real key and costs well under a cent, so it is a Mix task, never part of `mix test` or CI. The pure `Maya.Voice.WER` (word edit distance, name accuracy) is unit tested in CI.
- **Decision:** run at delay 480, and at 1200 if 480 loses; set `:stt_final` and the delay from the numbers and record them in ADR-009 and the PR.

### Testing the relay

A test-only Bandit WebSocket endpoint (Bandit 1.14.1 and WebSock 0.5.3 are already in `mix.lock`) plays a fake Mistral: it checks the `session.update` shape, echoes deltas, sends `transcription.done`, or errors, closes and stalls on demand. The relay's URL comes from config, so tests point it at `ws://localhost`. No new test dependency.

## Risks / Trade-offs

- [Realtime is less accurate than batch on short clips; Mistral recommends files for recorded audio] → the accuracy gate; batch final with realtime preview is a supported outcome.
- [400 bias terms may not fit the realtime context window, which is undocumented] → the spike sends the full list; on an `error` event, cap the realtime list lower and keep 400 for batch, and record it in ADR-009.
- [Public Preview: behavior or ids may change] → model id in config (`:stt_realtime_model`); batch fallback keeps Answers working.
- [WebSocket connect time (TLS plus upgrade) on each press] → connect at press while the Guest speaks; chunks queue meanwhile. If connect time hurts, keep one session warm per turn sequence (later, not in this change).
- [Five events a second through TalkLive and the Conversation] → small messages; check the Render CPU in the phone run.
- [Render to Mistral network drop mid-hold] → fallback to batch on the buffer, logged.

## Migration Plan

One additive migration: `turns.stt_source` (string, null for old and typed turns). Deploy as usual; rollback is reverting the PR (the upload path comes back with it). Config defaults keep batch as the final source until the eval numbers set it.

## Open Questions

- Does Abhishek want to record the 20 clips himself (preferred: real phone, real voice), or accept Voxtral TTS generated clips for a first pass? Either way the set is fixed once committed.
