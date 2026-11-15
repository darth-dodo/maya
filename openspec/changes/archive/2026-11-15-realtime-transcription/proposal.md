# Proposal

GitHub Issue: #75 (Block 7: Realtime transcription). Fast-tracked by Abhishek on 2026-11-15, with a yes to the frozen stack change (ADR-009) and the WebSocket client dependency. Builds after `warm-mic` (#94) and `transcript-edit` (#95) merge.

## Why

Today the Guest sees nothing until the whole clip is uploaded and batch STT returns, and every STT millisecond sits between release and Answer. Streaming the audio while the Talk button is held lets words appear in the Guest's bubble as they speak and leaves only the tail of the transcript for after release. Abhishek also reports many transcription errors, so this change measures accuracy against batch instead of assuming realtime is as good.

## What Changes

- **Streaming.** While held, the hook sends 16 kHz mono `pcm_s16le` chunks of about 200 ms over the LiveView socket (`pushEvent`, base64). The Conversation relays them to Voxtral realtime (`voxtral-mini-transcribe-realtime-3`, WebSocket) with `language: "en"` and the same `context_bias` names as batch. Text deltas appear live in `#live-question`. On release the final transcript goes through `Vocabulary.correct` and on to the `transcript-edit` countdown. The LiveView upload of a WAV clip is removed.
- **Accuracy gate.** A fixed set of 20 recorded test Questions (Pokémon names, places, gym leaders) in `test/fixtures/stt_eval/` is transcribed by batch and by realtime with `mix maya.stt_eval`, which prints word error rate and name accuracy for each. Realtime gives the final transcript only if it is at least as accurate on both; otherwise batch gives the final transcript (from the streamed audio, buffered on the server) and realtime is the live preview only. The choice is config (`:stt_final`), set from the numbers.
- **Fallback.** If the realtime connection fails, errors or does not finish in time, the buffered audio goes through batch STT and the reason is logged.
- **Latency.** Per-stage numbers before and after; `stt_ms` (release to final transcript) must drop. Each turn stores which STT gave the final text (`stt_source`).
- **Docs in the build PR.** ADR-009 "Realtime transcription" (Accepted, Abhishek 2026-11-15), the frozen stack table in CLAUDE.md and the `settled-architecture` skill, ARCHITECTURE.md voice loop, ADR-005 marked superseded in part (Questions no longer arrive as an upload).

Out of scope: realtime speech to speech (PHASE_2.md), browser Web Speech (rejected, PRODUCT.md), a direct browser to Mistral connection, turn detection and diarization, AudioWorklet.

## Capabilities

### Modified Capabilities
- `voice-loop`: Questions arrive as streamed audio; realtime STT with batch fallback; the accuracy gate; `stt_source` on the turn; live partial text.
- `talk-screen`: the button streams chunks while held instead of one upload on release; the live transcript bubble.

## Impact

- New dependency: `{:mint_web_socket, "~> 1.0"}` (1.0.6, released 2026-08-12), on top of Mint 1.11.0 already in `mix.lock` through Finch.
- Changed: `assets/js/talk_hook.js`, `lib/maya_web/live/talk_live.ex`, `lib/maya/conversation.ex`, `lib/maya/voice/` (new realtime relay, WAV builder, WER), `lib/mix/tasks/maya.stt_eval.ex`, `config/config.exs`, a migration adding `turns.stt_source`, tests, `test/fixtures/stt_eval/`.
- No new secret (same `MISTRAL_API_KEY`), no CSP change (the WebSocket to Mistral is server side), no new service.
- Cost: realtime is $0.008 per minute against $0.0035 for batch; a 5 s Question costs about $0.0007.
