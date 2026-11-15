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
| Cheap `/health` route outside the browser pipeline, used as `healthCheckPath` | all three | Done in #4, DB free so a paused Supabase does not restart the app |
| `render.yaml`: `region: frankfurt`, secrets `sync: false`, `preDeployCommand` for migrations | all three | Done in #4. Not `generateValue` for `SECRET_KEY_BASE`: 256 bits is shorter than the 64 bytes Phoenix needs |
| Paid web plan because a free-tier cold start breaks a latency budget | cantastorie (4s budget) | Done in #4: `0.5c-512mb`, DB on Supabase free (ADR-002) |
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
- Write the ADR success criteria with a cost per session and "degrade gracefully when the key is missing" (`docs/adr/ADR-010-deepgram-voice-stt-tts.md`). Maya's MVP shows Answers as text on a voice outage (PRODUCT.md); Web Speech is in PHASE_2.md.

## TTS lessons from cantastorie and habla-hermano (2026-11-15)

Read from each repo's origin/main. Items 1 to 7 are tracked as code changes in #96; the rest are decisions and notes.

1. **The iOS silent switch mutes Web Audio.** Set `navigator.audioSession.type` (cantastorie `docs/adr/ADR-010-audio-wake-and-stall-recovery.md`; habla-hermano 3fa68a7 plays a silent WAV for the same reason). Maya: test `"play-and-record"` vs `"playback"` on an iPhone, since Maya also records.
2. **After mic use, iOS can route speech to the earpiece** (habla-hermano `CHANGELOG.md`, `src/static/js/modules/voice-tts.js`). Every Maya turn is mic then playback: check it on the phone before changing code.
3. **Wake the AudioContext on every gesture and on return to view, and treat `"interrupted"` as not running** (cantastorie ADR-010; habla-hermano 3094ded, 7b247f2). Stop speech when the page goes to the background.
4. **`onended` never fires on a suspended context, so playback can hang silently.** Use a watchdog on `currentTime` (cantastorie ADR-010, 8db9df1 "never silent dead air"). Maya's `maybeIdle()` relies on `onended` alone.
5. **Drop a cut turn's late audio by turn id, not only by state** (habla-hermano 3094ded, generation counter).
6. **Log the provider's error body** (cantastorie 7869d98: 400s without a reason until the body was surfaced). Maya's TTS drops it today.
7. **The server ends every TTS stream with done or an error, also mid-stream** (habla-hermano 0ef9f03, `CHANGELOG.md`).
8. **Never change speech speed with Web Audio `playbackRate`**: it lowers the pitch like tape (habla-hermano dccfdd1). If Maya ever gets "talk slower", ask Voxtral for it (PHASE_2.md).
9. **Read the sample rate from the provider, never assume it** (cantastorie `_parse_pcm_params`; habla-hermano #92 garbled audio). Action: a test that pins the configured sample rate to the Voxtral docs (#96).
10. **Pin one voice for the persona** (habla-hermano ADR-011 "Achird"; cantastorie "Kore"). Maya's voice is the `:tts_voice` config value (Sky, since #48); changing it is a product decision.
11. **Opt out of provider data use and write down what leaves the server** (habla-hermano `provider.data_collection = "deny"`, Deepgram `mip_opt_out`). Maya: check Mistral's training opt-out and record it in ARCHITECTURE.md (privacy idea in PHASE_2.md).
12. **Cost:** Voxtral TTS is about $16 per million characters and about 70 ms model latency (cantastorie ADR-008 appendix), so a 2 to 3 sentence Answer (about 250 characters) costs about $0.004. ADR-008 also confirms calling Mistral directly beats OpenRouter's Voxtral (preset voices only).

No evidence in either repo on pronouncing Pokémon or place names, SSML, or cleaning markdown and emoji before TTS: Maya needs its own listening test.

Not copied: the `<audio>`/REST whole-clip fallback and OpenRouter or Gemini TTS (break ADR-005 streaming and the frozen stack), cantastorie's precomputed narration cache (Maya's Answers are live), browser speech fallbacks and silent keep-alive loops.

## Skipped

- Makefile with a `help` target: `mix` aliases (`mix precommit`) already cover it.
- Commitizen on `commit-msg`: with squash merges only the PR title lands on main.
- habla-hermano `.agentic-framework/` personas and workflows: too heavy, Superpowers covers the workflow.
- `tasks.md` as source of truth: GitHub Issues are the work queue.
- Sentry: not in the frozen stack. Ask before adding.
