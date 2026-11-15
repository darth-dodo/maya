# Tasks

## 1. Spike and baseline

- [ ] 1.1 Spike with the real key (no secrets printed): open the realtime WebSocket, send `session.update` (`pcm_s16le` 16000, `language` `en`, the 400 bias terms), stream one WAV fixture in 100 ms chunks, record the events and the time from `input_audio.end` to `transcription.done` in the PR. On 401, 403 or 404, stop and report on #75
  - Builder (#75): no key in the builder's environment. Written as `mix maya.stt_eval spike` (TTS speaks the Roxanne Question, streams it paced, prints events and end to done ms, raises "stop and report" on 401, 403 or 404); Abhishek runs it.
- [ ] 1.2 Baseline: `mix maya.latency` p50 and p95 per stage from production (the #40 Supabase query) with batch STT
- [ ] 1.3 Eval set: 20 clips and `questions.json` in `test/fixtures/stt_eval/` (script in design.md), each at most 5 s; verify the total is under 3.5 MB
  - Builder (#75): 1.2 needs the production database and 1.3 the key (Voxtral TTS clips, Abhishek's decision); `mix maya.stt_eval fixtures --voices ...` writes the set and prints its size.

## 2. Tests first

- [x] 2.1 Unit tests: `Maya.Voice.WER` (the spec's 0.2 and 0.0 example, punctuation, empty), the WAV header builder; verify they fail first
- [x] 2.2 Relay tests against a test-only Bandit WebSocket endpoint: settings message shape, chunks in order, deltas, done, error, close, done timeout; verify they fail first
- [x] 2.3 Conversation and LiveView tests: chunk validation (bad base64, over 16 KB, over 1 MB), partial text in `#live-question`, fallback to batch with the logged reason, `stt_final: :batch` path, one Question per hold, `stt_source` stored; verify they fail first
  - Builder (#75): written (`test/maya/conversation_stream_test.exs`, `talk_live_test.exs`); no local Postgres (Docker hung), so they ran in CI on PR #109: 256 of 256 green.

## 3. Build

- [x] 3.1 Add `{:mint_web_socket, "~> 1.0"}` (locks 1.0.6); `Maya.Voice.WER` and the WAV builder; verify 2.1 passes
- [x] 3.2 Realtime relay Task with Mint.WebSocket (connect, upgrade, settings, queue until `session.updated`, ping and close handling, done timeout), config for URL, model, delay and timeout; verify 2.2 passes
  - Builder (#75): audio queues until `session.created`, then `session.update` goes first on the same socket (documented lifecycle); a first frame in the same packet as the 101 is kept and decoded after the upgrade.
- [x] 3.3 Conversation: `stream_start`, `chunk`, `stream_end`, buffer, partials, fallback, `:stt_final`, migration for `turns.stt_source`; remove the upload path; verify 2.3 passes
- [x] 3.4 TalkHook and TalkLive: chunked int16 sends while held (pre-roll first), `stream_end` on release, `#live-question`; verify `mix assets.build` and a node check of the int16 conversion and chunk sizes
- [ ] 3.5 `mix maya.stt_eval` (batch and realtime, `--delay`), not run in CI; run it, record WER and name accuracy for both, set `:stt_final` and the delay from the numbers
  - Builder (#75): the task is built and tested against fakes; running it needs the key. `:stt_final` stays `:batch` and realtime is off (`MAYA_STT_REALTIME`) until the numbers exist.

## 4. Docs

- [ ] 4.1 ADR-009 "Realtime transcription" (Accepted, Abhishek 2026-11-15) with the eval numbers and the client choice; ADR-005 marked superseded in part; ADR index updated
- [x] 4.2 CLAUDE.md frozen stack and the `settled-architecture` skill table list Voxtral realtime and `mint_web_socket`; ARCHITECTURE.md voice loop diagram and STT bullet updated; GLOSSARY.md if a new term is used
  - Builder (#75): ADR-009 written with cost per Question and per hour; its eval table waits for 3.5. No new glossary term.

## 5. Verify

- [ ] 5.1 All gates (`factory:test`), each exit code checked
- [ ] 5.2 Phone check on iPhone and Android: live words appear while held, 10 holds make 10 Questions, barge-in and cancel still work; per-stage p50 and p95 before and after, with `stt_ms` lower, in the PR
- [ ] 5.3 Fallback check: a local run with a wrong realtime model id logs the reason and still answers through batch
  - Builder (#75): 5.2 and 5.3 need the key and a phone (Abhishek); the fallback paths are covered by tests (refused connection, error, close, done timeout).

## Workflow follow-up

- Archive the change in the same PR (`openspec-archive-change`).
