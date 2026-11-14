# Tasks

## 1. Spike

- [ ] 1.1 Write `scripts/voice_spike.sh` (WAV, MP4/AAC, WebM/Opus to STT; TTS pcm stream and wav header); verify `DRY_RUN=1` makes the three clips and exits 0; record results or "not run" in `design.md`

## 2. Pure core (tests first)

- [ ] 2.1 `Maya.Voice.SSE.parse/1` with split-chunk tests; verify red then green
- [ ] 2.2 `Maya.Voice.Latency.summary/1` with the p50/p95 scenario and missing stages; verify red then green

## 3. Shell

- [ ] 3.1 Config (`:voice`, `:mistral`), `MISTRAL_API_KEY` in `config/runtime.exs`, `render.yaml` (`sync: false`), `.env.template`; verify the docker smoke test
- [ ] 3.2 `Maya.Voice.STT` and `Maya.Voice.TTS` over Req with `Req.Test` stubs (success, error, empty text); verify tests
- [ ] 3.3 `turns` migration and `Maya.Voice.Turn`; `mix maya.latency`; verify tests
- [ ] 3.4 `Maya.Conversation` under DynamicSupervisor, Registry, Task.Supervisor; timing handler; echo, barge-in, outage and crash reload tests; verify tests

## 4. Screen

- [ ] 4.1 `TalkLive` at `/` (landing-page scenarios moved, empty-only badge case and facts, upload flow, voice down note); verify LiveView tests
- [ ] 4.2 `assets/js/talk_hook.js` state machine, WAV recording, PCM playback, barge-in, timing report; verify `mix assets.build` and screenshots at 375 px and 1280 px

## 5. Gates

- [ ] 5.1 Run `factory:test`; verify every gate is green and the coverage floor is not lowered
