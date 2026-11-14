# FACTORY.md: Maya Software Factory
Last updated: 14 Nov 2026

## Purpose
An agent-run pipeline that builds Maya from PRODUCT.md to a live Render deploy.
Human jobs: write PRODUCT.md, answer agents, tap Merge. Everything else is the factory.

## Product principle
Voice is the experience. Any Issue touching the voice loop must include a latency check in its "done when".

## Tools
| Tool | Role |
|---|---|
| Herdr | Local runtime. Hosts each agent in its own pane, tracks state, lets agents spawn and prompt each other via socket API |
| Claude Code | The agent in every pane |
| Matt Pocock skills | Upstream: grill, PRD, issues, code review |
| Superpowers (obra) | Downstream: plan, TDD, subagent execution, verify, finish branch |
| GitHub | Repo, Issues (work queue), PRs |
| GitHub Actions | CI checks and Telegram notifications |
| Render | Auto-deploy on merge to main (Frankfurt) |
| Telegram bot | Human gate: notifications, Merge/Hold buttons, replies to blocked agents, daily digest |

## Lines
| # | Line | Where | Skill / action | Output | Done when |
|---|---|---|---|---|---|
| 1 | Intake | Chat or Herdr pane `planner` | `grill-with-docs`, `to-prd` | PRODUCT.md | Committed |
| 2 | Plan | Pane `planner` | `to-issues` | ARCHITECTURE.md, GitHub Issues | Every Issue has a "done when" |
| 3 | Build | Pane `builder-<issue>` | Superpowers plan, TDD, subagents | Branch with code and tests | Tests pass locally |
| 4 | Verify | Pane `builder-<issue>` | Superpowers verify, finish branch | PR | PR opened, linked to Issue |
| 5 | Review | Pane `reviewer` (spawned by builder) | Matt `code-review` | PR review comments | No blocking comments |
| 6 | Check | GitHub Actions | `mix format --check-formatted`, `mix credo`, `mix test` | CI status | Green |
| 7 | Gate | Telegram | Merge / Hold buttons | Merge or hold | You tapped |
| 8 | Ship | Render | Auto-deploy from main | Live app | Health check passes |
| 9 | Feedback | Actions / watcher | Failures become Issues | New Issue | Back to line 3 |

## How it works

### The pipeline
```
 YOU                       AGENTS (Claude Code)                  MACHINES
 idea --> [1 Intake]  planner: grill-with-docs, to-prd -> PRODUCT.md
            |
          [2 Plan]    planner: to-issues, project-manager
            |           -> ARCHITECTURE.md + Issues (done when, estimate)
          [3 Build]   builder-<issue>: next-task, Superpowers plan, TDD
            |
          [4 Verify]  builder: definition of done -> PR (Closes #N)
            |
          [5 Review]  reviewer pane: code-review
            |
          [6 Check]  -------------------------------------> GitHub Actions
            |                compile, format, credo, test
 merge <- [7 Gate]    only Abhishek merges (squash, PR title)
            |
          [8 Ship]   -------------------------------------> Render <-> Supabase
            |                migrate, /health, live
          [9 Feedback] failures become Issues --> back to [3]
```

### One Issue's life
```
Issue #12 "find_pokemon tool" (done when, estimate 1h)
  -> builder picks it (next-task: stale loops, green PRs, red PRs, then new)
  -> branch feat/find-pokemon: test first, code, mix precommit
  -> PR "feat: add find_pokemon tool", Closes #12
  -> CI red: builder fixes (systematic-debugging). CI green: wait for merge
  -> Abhishek squash merges
  -> Render: CI passed, /app/bin/migrate, /health ok, live
  -> Issue closes, next-task picks the next one
```

### Guardrails that agents cannot talk past
| Risk | Stopped by | Where |
|---|---|---|
| Agent merges its own PR | `gh pr merge` denied | `.claude/settings.json` |
| Push to main, force push | Branch protection, admins included | GitHub settings |
| Broken code ships | Required `test` check, Render `autoDeployTrigger: checksPass` | GitHub, `render.yaml` |
| Stack drift | `settled-architecture` red flags, ADR for any change | Repo |
| "Works on my machine" | Definition of done with evidence | `CLAUDE.md`, PR template |
| Scope creep | New ideas go to `PHASE_2.md` | Repo |
| Overrun | 2x estimate means a cut, F1 past 3h means build by hand | `project-manager` skill |
| Leaked secrets | `.env` git and Docker ignored and read denied, secrets `sync: false` | Repo, Render |

Critical rules are enforced by machines that ignore prompts (GitHub, the permission deny list, Render). Skills only make the right path the easy one.

## Skill ownership rules
1. One owner per station. Matt owns intake, plan, review. Superpowers owns build and verify.
2. TDD: Superpowers only. Do not invoke Matt `tdd`.
3. Superpowers auto-triggers via SessionStart hook. Disable it in the `planner` pane, or accept its brainstorming at intake. Decide in F1.
4. Run `/setup-matt-pocock-skills` once: tracker = GitHub, docs = `docs/`.

## Herdr layout
- `planner`: lines 1 and 2. Long-lived.
- `builder-<issue>`: one per Issue. Max 2 in parallel (avoid merge conflicts, protect API budget).
- `reviewer`: spawned by builder via `herdr agent start reviewer`, prompted with `--wait`, read back.
- Fan-out inside a build: Superpowers subagents, not new Herdr panes.

## Telegram watcher (local script)
1. Poll Herdr for `blocked` or `done` panes. Message me.
2. Poll Telegram `getUpdates` (no public endpoint needed).
3. Merge tap: `gh pr merge <n> --squash`. Always answer the callback query.
4. Text reply to a blocked-pane message: forward into that pane.
5. 21:00 digest: merged PRs, open Issues, blocked panes, CI failures.
6. CI posts pass/fail directly via `curl` to the Bot API.

## Secrets
| Secret | Lives in |
|---|---|
| `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID` | GitHub Actions secrets, local `.env` |
| `OPENROUTER_API_KEY`, `MISTRAL_API_KEY` | Render env, local `.env` |
| `BASIC_AUTH_USER`, `BASIC_AUTH_PASS` | Render env |
| `DATABASE_URL` | Render (auto) |

Never commit `.env`. Add it to `.gitignore` in F1.

## Weekend plan
Sat
- F1 Skeleton (1.5h): repo, CI workflow, Render auto-deploy, Herdr, Claude Code, both plugins, setup skill. Done when a dummy PR passes CI and merge deploys a hello page.
- F2 PRODUCT.md (1h): grill session. Done when committed.
- F3 Plan (0.5h): ARCHITECTURE.md and Issues. Done when every Issue has a "done when".
- F4 Telegram (0.5h): bot and watcher. Done when tapping Merge on my phone merges a dummy PR.
- Factory builds Maya Blocks 1 to 3. I review, merge, play a gym.

Sun
- Factory builds Maya Blocks 4 to 7. Done when I ask about Roxanne out loud and hear the answer.

## Guardrails
- Kill switch: F1 past 3h means build Maya by hand with Claude Code. Factory moves to PHASE_2.md.
- Cut order: digest, Herdr watcher (check panes manually), then MVP cuts (embeddings, journal, dials).
- One block at a time. Stop at "done when". Past 2x estimate, take the cut.
- Gym rule: at least one gym per build day.
- New ideas go to PHASE_2.md.

## Known limits
- Herdr is local. Factory runs only while my machine is on.
- Agents need tool permissions pre-approved per pane, or they block (Telegram will ping).
- Herdr agent detection relies on process names and output, so it can misread a new CLI version.

## Sources
- Herdr: https://www.mindstudio.ai/blog/herder-terminal-agent-multiplexer/
- Herdr launch: https://aiunderstanding.org/news/herdr-launches-open-source-terminal-for-managing-multiple-ai-coding-agents
- Superpowers: https://github.com/obra/superpowers
- Matt Pocock skills: https://github.com/mattpocock/skills
- Telegram Bot API: https://core.telegram.org/bots/api
- Telegram webhooks vs polling: https://hookdeck.com/webhooks/platforms/guide-to-telegram-webhooks-features-and-best-practices
- Render pricing: https://render.com/pricing.md
