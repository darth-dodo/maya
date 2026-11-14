# Changelog

All notable changes to Maya are listed here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Commits follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

Every PR adds its lines under `Unreleased` (Added, Changed, Fixed, Removed), ending with the PR number.

## [Unreleased]

### Added
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

### Changed
- Supabase CA certificate shipped in `priv/certs/` instead of the `DATABASE_CA_CERT` env var (#5)
- Prod database connects to Supabase with verified SSL; LiveView host falls back to `RENDER_EXTERNAL_HOSTNAME` (#4)
- Project name written as "Maya", never all caps, across docs and skills (#2)
