# Factory learnings from sibling repos
Last updated: 14 Nov 2026

What Maya takes from `cantastorie`, `habla-hermano` and `voxpopuli`, and when.
"Now" items ship in the PR that adds this file. Later items are tied to an F1 step or Maya block so they land when they are needed, not before.

## Adopted now

| Practice | Source | In Maya |
|---|---|---|
| Settled architecture skill with "explicitly NOT" list and red flags | cantastorie `.claude/skills/settled-architecture` | `.claude/skills/settled-architecture/SKILL.md` |
| Next-task skill: gather git + PR + Issue state, rank what to do next | cantastorie `.claude/skills/next-task` | `.claude/skills/next-task/SKILL.md` (GitHub Issues instead of Linear) |
| Definition of done: "code works is not done" | voxpopuli `vp-complete-milestone`, habla-hermano quality gates | "Definition of done" in `CLAUDE.md` |
| ADR convention: `NNN-kebab-title.md`, status, index | cantastorie `docs/adr/README.md`, voxpopuli `docs/adr/` | `docs/adr/README.md` |
| Acceptance criteria and how each was verified, in the PR body | cantastorie plans | `.github/pull_request_template.md` |
| Tracked, curated permission allowlist (habla-hermano's grew prompt by prompt) | habla-hermano, cantastorie `settings.local.json` (lesson, not copy) | `.claude/settings.json`, with `gh pr merge` denied to keep the human gate. Edits to it are Abhishek's call |
| Real PHASE_2 file instead of a section | FACTORY.md rule, no sibling had one | `PHASE_2.md` |

## Adopt later

| Practice | Source | When |
|---|---|---|
| `ci-success` job that aggregates all jobs with `if: always()`, used as the single required check | cantastorie, habla-hermano `ci.yml` | With branch protection, after PR #1 merges |
| Cheap `/health` route outside the browser pipeline, used as `healthCheckPath` | all three | F1 step 4 (Render) |
| `render.yaml`: `region: frankfurt`, secrets `sync: false`, `generateValue: true` for `SECRET_KEY_BASE`, `preDeployCommand` for migrations | all three | F1 step 4 |
| `plan: starter` because a free-tier cold start breaks a latency budget | cantastorie (4s budget) | F1 step 4, needs Abhishek's approval (paid) |
| Preview environments that expire after 3 days, with `previewValue` blanking write keys | cantastorie, voxpopuli | After MVP, only if previews are wanted |
| Per-stage timing with run ids in log metadata (`timed_step` in Python) | cantastorie `src/observability.py`, voxpopuli SSE `done` timings | First voice block: `:telemetry.span/3` per stage (mic release, STT, agent, TTS first byte, playback start) |
| Black-box eval harness: cases JSON, weighted evaluators, latency p50/p95 per stage, errored runs excluded, `--baseline` diff, `LESSONS.md` | voxpopuli `evals/` | After the agent loop exists. Add a spoiler-leak evaluator next to source accuracy |
| Pre-commit hooks: private key, merge conflict, large file, detect-secrets | cantastorie, habla-hermano | Only if asked: needs a Python tool (`pre-commit`) on the machine |

## Voice lessons from habla-hermano

Read before building the voice loop.

- Proxy STT and TTS through the server so API keys never reach the browser (`src/api/routes/voice.py`). In Maya: one GenServer per voice session, under a supervisor.
- WebSocket TTS gave a faster first byte than REST (`docs/plans/2026-03-17-websocket-tts-design.md`).
- Check the audio formats the provider streams. Deepgram streamed raw PCM, not mp3, and the client had to add a WAV header (`docs/plans/2026-04-06-fix-websocket-tts.md`). Verify this for Voxtral TTS 3 before writing playback code.
- Browser voice code raced: iOS AudioContext unlock, `onended` not firing, frames sent before the pipeline was ready, double play. The fix was a small finite state machine plus one AbortController per session (`docs/design/phase21-voice-fsm-refactor.md`). In Maya: build the LiveView JS hook as an explicit state machine from day one.
- Write the ADR success criteria with a cost per session and "degrade gracefully when the key is missing" (`docs/adr/ADR-010-deepgram-voice-stt-tts.md`). Maya's fallback is the browser Web Speech API.

## Skipped

- Makefile with a `help` target: `mix` aliases (`mix precommit`) already cover it.
- Commitizen on `commit-msg`: with squash merges only the PR title lands on main.
- habla-hermano `.agentic-framework/` personas and workflows: too heavy, Superpowers covers the workflow.
- `tasks.md` as source of truth: GitHub Issues are the work queue.
- Sentry: not in the frozen stack. Ask before adding.
