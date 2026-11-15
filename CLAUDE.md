# CLAUDE.md: Maya Handoff for Claude Code
Last updated: 14 Nov 2026

Read this first, then FACTORY.md, then AGENTS.md (Phoenix generator guidelines). Repo: `maya`.

## Who you work for
- Abhishek. Prefers small, finishable blocks with a clear "done when".
- Crisp answers. Cite sources (docs links) for any library or API claim.
- No em or en dashes in anything you write.
- Write the name as "Maya" (or "maya" for repo, paths and code). Never all caps.
- Scope creep guard: new ideas go to PHASE_2.md, never into the MVP.

## What we are building
Maya = Maps, Answers, Yaps, Advice. A talking, spoiler-free Pokémon Emerald companion on a phone.
Push to talk, ask out loud, hear a short answer based on current badges and team.

## Two goals this weekend
1. Build the software factory (FACTORY.md).
2. Let the factory build the Maya MVP.

## Product principle
Voice is the experience. Every decision optimizes the push-to-talk loop: latency, reliability, short spoken answers.
Elixir is chosen for this: one supervised process per voice session, streaming over the LiveView socket, crash recovery without dropping the user.
Track latency per stage (mic release, STT, agent, TTS first byte, playback start) from day one.

## Frozen MVP stack (do not change without asking)
- Elixir, Phoenix + LiveView
- Postgres + pgvector (`{:pgvector, "~> 0.4"}`) on Supabase free, Ireland (eu-west-1), via the session pooler on port 5432 (ADR-002)
- OpenRouter for the agent: tool calling via Req, model name in config
- Mistral Voxtral: `voxtral-mini-transcribe-3` (STT), Voxtral TTS 3
- Mistral embeddings API (Bumblebee is too big for Render 512 MB)
- Render web service `0.5c-512mb`, Frankfurt (permanent), Plug.BasicAuth
- Hand-written GenServer agent loop. No agent library.

## Knowledge source
1. Postgres tables from pret/pokeemerald `wild_encounters.json`, `src/data/trainer_parties.h`, and PokeAPI (Emerald). Imported via Mix tasks.
2. pgvector: walkthrough notes by location, tagged `badge_required` (spoiler guard).
3. `progress.json`: the seed for Progress (badges, team, location, settings), imported once into Postgres (ADR-006).

## Agent tools (Maya runtime)
`find_pokemon(name)`, `gym_counter(leader, my_team)`, `search_guide(query)` filtered by badges, `set_setting(name, value)`, `log_event(text)`

## Personality
Human-like, opinions, catchphrase, journal memory. Voice answers: 2 to 3 sentences.
Dials: humor 75, honesty 90, sass 40, spoilers 0 (locked), Mudkip hype 100.

## Current status
- FACTORY.md: done.
- PRODUCT.md: done (F2, `grill-with-docs` on 2026-11-14). Terms in GLOSSARY.md; facts only from tools (ADR-004).
- ARCHITECTURE.md: done (F3, grilling on 2026-11-14; ADR-005 voice transport, ADR-006 state in Postgres). Next: the 5 block Issues after Abhishek's yes, then factory:plan per block.
- F1 step 1 done: Phoenix 1.8.16 app generated (Elixir 1.20.5 / OTP 29 via Homebrew).

## Your first task: F1 Factory skeleton (1.5h, kill switch at 3h)
Do these in order. Stop at each "done when" and report.

1. **Repo.** `mix phx.new maya`, `git init`, `.gitignore` includes `.env`. Push to GitHub. Done when main exists on GitHub.
2. **Local DB.** Docker `pgvector/pgvector:pg17`, `mix ecto.create`. Done when the app runs at localhost:4000.
3. **CI.** `.github/workflows/ci.yml` with a Postgres + pgvector service: `mix format --check-formatted`, `mix credo`, `mix test`. Add `credo` dep. Done when CI is green on a PR.
4. **Render.** `render.yaml` blueprint: web service, region frankfurt, deploy from main after CI passes, Postgres on Supabase (ADR-002). Pre-deploy command runs migrations. Done when merging to main deploys the hello page over HTTPS.
5. **Plugins.** Install Superpowers and Matt Pocock skills. Run `/setup-matt-pocock-skills` (tracker: GitHub, docs: `docs/`). Done when both are listed and setup config is committed.
6. **Runtime.** Claude Code sessions: `planner` and `builder-<issue>` (own worktree via `claude -w`), Remote Control on. Herdr optional for devex (installed, see FACTORY.md "Runtime"). Done when both sessions run and show in Remote Control.
7. **Proof.** A dummy PR (edit hello page text) goes through CI and deploys. Done when the change is live.

Ask me before: choosing Render plan tier, any paid service, or changing the frozen stack. (Superpowers SessionStart hook: decided, kept in every pane, see FACTORY.md skill ownership rule 3.)

## After F1
- F2: run the grill (`grill-with-docs`) with me to write PRODUCT.md. Resume at Q1.
- F3: write ARCHITECTURE.md, then `openspec-propose` one change per block and one GitHub Issue per change (`project-manager`). Every Issue has a "done when".
- F4: Telegram moved to PHASE_2.md. Phone gate: GitHub app to merge, Remote Control for blocked sessions.

## Rules
- One block at a time. Stop at "done when". Past 2x estimate, take the cut.
- Factory freeze (decided 2026-11-14): after #19, #20 and changelog fragments, factory changes are fixes only until Maya Block 1 ships. F2 (PRODUCT.md) is done; next is F3. The planned `onboarding` and `coverage-88` changes wait until after Block 1. New factory ideas go to PHASE_2.md.
- Cut order: embeddings, journal, dials (Telegram digest and watcher already in PHASE_2.md).
- Voice outage: Answers show as text with a "voice is down" note (decided in PRODUCT.md; no Web Speech fallback).
- TDD via Superpowers only. Do not use Matt `tdd`. Enforced: `.claude/settings.json` denies `mattpocock-skills:tdd` and `mattpocock-skills:diagnosing-bugs` (Superpowers owns build and debug).
- Max 2 builders in parallel. Squash merges.
- Never commit secrets. See FACTORY.md for where each one lives.
- Remind me: at least one gym per build day.

## Definition of done
Code that works is not done. Done means all of these, with evidence in the PR:
1. Every "done when" item in the Issue is met, each shown with a command, curl or screenshot.
2. `mix precommit` and `mix credo` are green locally. Never `--no-verify`.
3. Voice loop touched: per-stage latency numbers, before and after.
4. Docs match the code: CLAUDE.md, an ADR in `docs/adr/` if a settled choice changed, and the Issue's OpenSpec change archived (`openspec-archive-change`) in the same PR.
5. PR open with `Closes #N` and CI green. Abhishek merges. Agents never merge.

## Factory conventions
- Commits and PR titles: Conventional Commits (`feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`). The squash merge uses the PR title, so the title must follow it too.
- Every PR adds a changelog fragment `changelog.d/<branch-with-dashes>.md` (lines like `Added: ...`, no PR number). Never edit `CHANGELOG.md` in a feature PR; `release-manager` folds fragments in.
- Factory entry points: `factory:plan`, `factory:build`, `factory:test`, `factory:review`, plus `factory:pause`, `factory:resume`, `factory:cleanup`, and the flywheel `factory:retro`, `factory:improve`, `factory:recap` (FACTORY.md "Skills by station", "Flywheel").
- Project skills: `settled-architecture` (before adding anything outside the stack), `next-task` (what to do next), `project-manager` (Issues, estimates, cuts, status), `release-manager` (versions, tags, release notes), `herdr` (optional, only inside a Herdr pane), `quiz-me` (5 question spaced-repetition quiz on the codebase; log in `~/coding-tutor-tutorials/maya/`).
- New ideas: one line in `PHASE_2.md`.
- Decisions: `docs/adr/` (see its README).
- What we took from sibling repos and what lands later: `docs/factory-learnings.md`. Read its voice lessons before building the voice loop.

## Agent skills

### Issue tracker

GitHub Issues on darth-dodo/maya, via the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Specs

OpenSpec: `openspec/specs/` is the source of truth for behaviour, `openspec/changes/<id>/` holds proposals. Build from `tasks.md` with Superpowers; `openspec-apply-change` is denied (ADR-003).

### Domain docs

Single-context: `GLOSSARY.md` and `docs/adr/` at the repo root. See `docs/agents/domain.md`.

## Gotchas
- Not every OpenRouter model supports tools. `tool_calls` is an array; each `arguments` is a JSON string. Parse each.
- Browser mic needs HTTPS. Test on phone only after Render deploy.
- Telegram: always answer the callback query after a button press, or the button spins forever.
- `getUpdates` and webhooks are mutually exclusive. Watcher uses polling.
- Sessions (and optional Herdr) are local. Factory runs only while my machine is on.
- Sesame has a voice model also named Maya. Avoid confusion in docs and search.
- Supabase free pauses after 1 week of inactivity: restore it in the dashboard. Connect through the session pooler (port 5432); direct connections are IPv6 only.
- Render deploys and ops: `render-deploy` skill.

## PHASE_2.md (do not build)
See `PHASE_2.md`.

## Sources
- Phoenix install: https://hexdocs.pm/phoenix/installation.html
- pgvector-elixir: https://hexdocs.pm/pgvector/readme.html
- OpenRouter tool calling: https://openrouter.ai/docs/guides/features/tool-calling
- Mistral Voxtral 3: https://mistral.ai/news/voxtral-3/
- Mistral audio API: https://docs.mistral.ai/studio-api/audio
- Render pricing: https://render.com/pricing.md
- PokeAPI: https://pokeapi.co/
- Herdr (optional): https://github.com/herdrdev/herdr
- Superpowers: https://github.com/obra/superpowers
- Matt Pocock skills: https://github.com/mattpocock/skills
- Telegram Bot API: https://core.telegram.org/bots/api
