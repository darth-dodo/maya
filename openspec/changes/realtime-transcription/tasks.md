# Tasks

## 1. Spike and baseline

- [ ] 1.1 Spike with the real key (no secrets printed): open the realtime WebSocket, send `session.update` (`pcm_s16le` 16000, `language` `en`, the 400 bias terms), stream one WAV fixture in 100 ms chunks, record the events and the time from `input_audio.end` to `transcription.done` in the PR. On 401, 403 or 404, stop and report on #75
- [ ] 1.2 Baseline: `mix maya.latency` p50 and p95 per stage from production (the #40 Supabase query) with batch STT
- [ ] 1.3 Eval set: 20 clips and `questions.json` in `test/fixtures/stt_eval/` (script in design.md), each at most 5 s; verify the total is under 3.5 MB

## 2. Tests first

- [ ] 2.1 Unit tests: `Maya.Voice.WER` (the spec's 0.2 and 0.0 example, punctuation, empty), the WAV header builder; verify they fail first
- [ ] 2.2 Relay tests against a test-only Bandit WebSocket endpoint: settings message shape, chunks in order, deltas, done, error, close, done timeout; verify they fail first
- [ ] 2.3 Conversation and LiveView tests: chunk validation (bad base64, over 16 KB, over 1 MB), partial text in `#live-question`, fallback to batch with the logged reason, `stt_final: :batch` path, one Question per hold, `stt_source` stored; verify they fail first

## 3. Build

- [ ] 3.1 Add `{:mint_web_socket, "~> 1.0"}` (locks 1.0.6); `Maya.Voice.WER` and the WAV builder; verify 2.1 passes
- [ ] 3.2 Realtime relay Task with Mint.WebSocket (connect, upgrade, settings, queue until `session.updated`, ping and close handling, done timeout), config for URL, model, delay and timeout; verify 2.2 passes
- [ ] 3.3 Conversation: `stream_start`, `chunk`, `stream_end`, buffer, partials, fallback, `:stt_final`, migration for `turns.stt_source`; remove the upload path; verify 2.3 passes
- [ ] 3.4 TalkHook and TalkLive: chunked int16 sends while held (pre-roll first), `stream_end` on release, `#live-question`; verify `mix assets.build` and a node check of the int16 conversion and chunk sizes
- [ ] 3.5 `mix maya.stt_eval` (batch and realtime, `--delay`), not run in CI; run it, record WER and name accuracy for both, set `:stt_final` and the delay from the numbers

## 4. Docs

- [ ] 4.1 ADR-009 "Realtime transcription" (Accepted, Abhishek 2026-11-15) with the eval numbers and the client choice; ADR-005 marked superseded in part; ADR index updated
- [ ] 4.2 CLAUDE.md frozen stack and the `settled-architecture` skill table list Voxtral realtime and `mint_web_socket`; ARCHITECTURE.md voice loop diagram and STT bullet updated; GLOSSARY.md if a new term is used

## 5. Verify

- [ ] 5.1 All gates (`factory:test`), each exit code checked
- [ ] 5.2 Phone check on iPhone and Android: live words appear while held, 10 holds make 10 Questions, barge-in and cancel still work; per-stage p50 and p95 before and after, with `stt_ms` lower, in the PR
- [ ] 5.3 Fallback check: a local run with a wrong realtime model id logs the reason and still answers through batch

## Workflow follow-up

- Archive the change in the same PR (`openspec-archive-change`).
