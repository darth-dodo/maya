# Changelog

All notable changes to MAYA are listed here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Commits follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

Every PR adds its lines under `Unreleased` (Added, Changed, Fixed, Removed), ending with the PR number.

## [Unreleased]

### Added
- Factory docs from sibling repos: `settled-architecture` and `next-task` skills, definition of done, ADR convention, PR template, `PHASE_2.md`, this changelog (#2)
- `.claude/settings.json` allowlist for mix, git read and `gh` commands, denying `gh pr merge`, force pushes, pushes to main and reading `.env` (#2)
- `release-manager` and `project-manager` project skills (#2)
- CI on GitHub Actions with a pgvector Postgres service: compile warnings as errors, format check, credo, tests (#1)
- Credo as a dev and test dependency (#1)
- `docker-compose.yml` for a local pgvector Postgres bound to localhost (#1)
- Phoenix 1.8.16 LiveView app scaffold, CLAUDE.md and FACTORY.md handoff docs
