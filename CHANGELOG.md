# Changelog

All notable changes to Maya are listed here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Commits follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

Every PR adds its lines under `Unreleased` (Added, Changed, Fixed, Removed), ending with the PR number.

## [Unreleased]

### Added
- `quiz-me` skill: on-demand 5 question quiz on recent PRs, specs and ADRs, code structure and factory ops, with spaced repetition borrowed from coding-tutor (#14)
- OpenSpec 2.0 for the spec station: `openspec/` (config with Maya context and rules), six skills in `.agents/skills/` linked from `.claude/skills/`; ADR-003 (#11)
- Factory runtime without Herdr: Claude Code sessions, worktree builders, reviewer subagent, Remote Control for the phone; Herdr kept as an optional devex layer with its skill (`.claude/skills/herdr/`, Herdr 0.9.5) (#10)
- Permission deny rules for `mattpocock-skills:tdd` and `mattpocock-skills:diagnosing-bugs`, so Superpowers keeps TDD and debugging (#9)
- Matt Pocock skills setup: `docs/agents/` (GitHub tracker, default triage labels, single-context domain docs) and an Agent skills section in CLAUDE.md (#9)
- `.env.template` listing every env var, with the Supabase pooler URI format (#6)
- Render deploy: `render.yaml` (Frankfurt, `0.5c-512mb`, deploy after CI, migrations pre-deploy), release Dockerfile, `/health` route, `render-deploy` skill (#4)
- ADR-002: Postgres on Supabase (#4)
- ADR-001: agent-run software factory, why, what and how, with a Mermaid pipeline diagram and guardrails; "How it works" section in FACTORY.md (#3)
- Factory docs from sibling repos: `settled-architecture` and `next-task` skills, definition of done, ADR convention, PR template, `PHASE_2.md`, this changelog (#2)
- `.claude/settings.json` allowlist for mix, git read and `gh` commands, denying `gh pr merge`, force pushes, pushes to main and reading `.env` (#2)
- `release-manager` and `project-manager` project skills (#2)
- CI on GitHub Actions with a pgvector Postgres service: compile warnings as errors, format check, credo, tests (#1)
- Credo as a dev and test dependency (#1)
- `docker-compose.yml` for a local pgvector Postgres bound to localhost (#1)
- Phoenix 1.8.16 LiveView app scaffold, CLAUDE.md and FACTORY.md handoff docs

### Fixed
- App refuses to boot when `SECRET_KEY_BASE` is under 64 bytes, so a bad key fails the deploy instead of serving 500s (#8)

### Changed
- Plan station: one OpenSpec change and one GitHub Issue per block; builders archive the change in their PR. Matt `to-spec` and `to-tickets` retired (#11)
- Telegram bot and watcher (F4) moved to PHASE_2.md (#10)
- Superpowers SessionStart hook kept in every pane, planner included; intake invokes `grill-with-docs` explicitly (#10)
- Skill names updated to the current Matt Pocock set: `to-spec` and `to-tickets` replace `to-prd` and `to-issues` (#9)
- Supabase project recorded as Ireland (eu-west-1); `DATABASE_URL` pitfalls (API URL, direct host, port 6543) and a local connection test documented (#7)
- Supabase CA certificate shipped in `priv/certs/` instead of the `DATABASE_CA_CERT` env var (#5)
- Prod database connects to Supabase with verified SSL; LiveView host falls back to `RENDER_EXTERNAL_HOSTNAME` (#4)
- Project name written as "Maya", never all caps, across docs and skills (#2)
