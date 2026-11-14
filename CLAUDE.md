# CLAUDE.md: MAYA Handoff for Claude Code
Last updated: 14 Nov 2026

Read this first, then FACTORY.md, then AGENTS.md (Phoenix generator guidelines). Repo: `maya`.

## Who you work for
- Abhishek. Prefers small, finishable blocks with a clear "done when".
- Crisp answers. Cite sources (docs links) for any library or API claim.
- No em or en dashes in anything you write.
- Scope creep guard: new ideas go to PHASE_2.md, never into the MVP.

## What we are building
MAYA = Maps, Answers, Yaps, Advice. A talking, spoiler-free Pokemon Emerald companion on a phone.
Push to talk, ask out loud, hear a short answer based on current badges and team.

## Two goals this weekend
1. Build the software factory (FACTORY.md).
2. Let the factory build the MAYA MVP.

## Product principle
Voice is the experience. Every decision optimizes the push-to-talk loop: latency, reliability, short spoken answers.
Elixir is chosen for this: one supervised process per voice session, streaming over the LiveView socket, crash recovery without dropping the user.
Track latency per stage (mic release, STT, agent, TTS first byte, playback start) from day one.

## Frozen MVP stack (do not change without asking)
- Elixir, Phoenix + LiveView
- Postgres + pgvector (`{:pgvector, "~> 0.4"}`)
- OpenRouter for the agent: tool calling via Req, model name in config
- Mistral Voxtral: `voxtral-mini-transcribe-3` (STT), Voxtral TTS 3
- Mistral embeddings API (Bumblebee is too big for Render 512 MB)
- Render, Frankfurt (permanent), Plug.BasicAuth
- Hand-written GenServer agent loop. No agent library.

## Knowledge source
1. Postgres tables from pret/pokeemerald `wild_encounters.json`, `src/data/trainer_parties.h`, and PokeAPI (Emerald). Imported via Mix tasks.
2. pgvector: walkthrough notes by location, tagged `badge_required` (spoiler guard).
3. `progress.json`: badges, team, location, personality settings.

## Agent tools (MAYA runtime)
`find_pokemon(name)`, `gym_counter(leader, my_team)`, `search_guide(query)` filtered by badges, `set_setting(name, value)`, `log_event(text)`

## Personality
Human-like, opinions, catchphrase, journal memory. Voice answers: 2 to 3 sentences.
Dials: humor 75, honesty 90, sass 40, spoilers 0 (locked), Mudkip hype 100.

## Current status
- FACTORY.md: done.
- PRODUCT.md: not started. Grill session paused at Q1.
  - Q1 draft answer: "I'm stuck mid-route or before a gym. I hold the button, ask one question out loud, and within 5 seconds I hear a 2 to 3 sentence answer that fits my badges and team, with zero spoilers." Not yet confirmed.
- F1 step 1 done: Phoenix 1.8.16 app generated (Elixir 1.20.5 / OTP 29 via Homebrew).

## Your first task: F1 Factory skeleton (1.5h, kill switch at 3h)
Do these in order. Stop at each "done when" and report.

1. **Repo.** `mix phx.new maya`, `git init`, `.gitignore` includes `.env`. Push to GitHub. Done when main exists on GitHub.
2. **Local DB.** Docker `pgvector/pgvector:pg17`, `mix ecto.create`. Done when the app runs at localhost:4000.
3. **CI.** `.github/workflows/ci.yml` with a Postgres + pgvector service: `mix format --check-formatted`, `mix credo`, `mix test`. Add `credo` dep. Done when CI is green on a PR.
4. **Render.** `render.yaml` blueprint: web service + Postgres, region frankfurt, auto-deploy from main. Release command runs migrations. Done when merging to main deploys the hello page over HTTPS.
5. **Plugins.** Install Superpowers and Matt Pocock skills. Run `/setup-matt-pocock-skills` (tracker: GitHub, docs: `docs/`). Done when both are listed and setup config is committed.
6. **Herdr.** Install, run `herdr integration install claude`. Create panes `planner` and `builder-1`. Done when Herdr shows both panes with correct state.
7. **Proof.** A dummy PR (edit hello page text) goes through CI and deploys. Done when the change is live.

Ask me before: choosing Render plan tier, any paid service, changing the frozen stack, or deciding the Superpowers SessionStart hook question in the planner pane.

## After F1
- F2: run the grill (`grill-with-docs`, then `to-prd`) with me to write PRODUCT.md. Resume at Q1.
- F3: `to-issues`, write ARCHITECTURE.md. Every Issue has a "done when".
- F4: Telegram bot + local watcher (see FACTORY.md). Done when tapping Merge on my phone merges a dummy PR.

## Rules
- One block at a time. Stop at "done when". Past 2x estimate, take the cut.
- Cut order: Telegram digest, Herdr watcher, embeddings, journal, dials.
- Voice fallback: browser Web Speech API.
- TDD via Superpowers only. Do not use Matt `tdd`.
- Max 2 builders in parallel. Squash merges.
- Never commit secrets. See FACTORY.md for where each one lives.
- Remind me: at least one gym per build day.

## Definition of done
Code that works is not done. Done means all of these, with evidence in the PR:
1. Every "done when" item in the Issue is met, each shown with a command, curl or screenshot.
2. `mix precommit` and `mix credo` are green locally. Never `--no-verify`.
3. Voice loop touched: per-stage latency numbers, before and after.
4. Docs match the code: CLAUDE.md, and an ADR in `docs/adr/` if a settled choice changed.
5. PR open with `Closes #N` and CI green. Abhishek merges. Agents never merge.

## Factory conventions
- Project skills: `settled-architecture` (before adding anything outside the stack), `next-task` (what to do next).
- New ideas: one line in `PHASE_2.md`.
- Decisions: `docs/adr/` (see its README).
- What we took from sibling repos and what lands later: `docs/factory-learnings.md`. Read its voice lessons before building the voice loop.

## Gotchas
- Not every OpenRouter model supports tools. `tool_calls` is an array; each `arguments` is a JSON string. Parse each.
- Browser mic needs HTTPS. Test on phone only after Render deploy.
- Telegram: always answer the callback query after a button press, or the button spins forever.
- `getUpdates` and webhooks are mutually exclusive. Watcher uses polling.
- Herdr is local. Factory runs only while my machine is on.
- Sesame has a voice model also named Maya. Avoid confusion in docs and search.
- Verify Render Postgres supports the `vector` extension on the chosen plan before step 4.

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
- Herdr: https://www.mindstudio.ai/blog/herder-terminal-agent-multiplexer/
- Superpowers: https://github.com/obra/superpowers
- Matt Pocock skills: https://github.com/mattpocock/skills
- Telegram Bot API: https://core.telegram.org/bots/api
