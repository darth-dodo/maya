# Changelog

All notable changes to Maya are listed here.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Commits follow [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).

PRs add a fragment in `changelog.d/` (see its README) instead of editing this file; `release-manager` folds fragments in at release time.

## [Unreleased]

## [0.1.0] - 2026-11-14

### Added
- PRODUCT.md from the grill-with-docs session, GLOSSARY.md, and ADR-004 (facts only from tools and data) (#27)
- Pokemon themed welcome page: Emerald edition CSS Poke Ball on a calm tide backdrop, Mudkip hype line, spoiler-free badge case with 8 empty slots; app header shows only the Maya wordmark and theme toggle; id-based landing-page tests; coverage floor raised to 38% (#24)
- Three Gemini-generated backdrop images (tide, dusk, night) in `priv/static/images/backdrops/`; the home page uses tide (#24)
- Factory flywheel: `factory:retro` (metrics row and one lesson per merged PR in `~/maya-factory/`), `factory:improve` (one measured experiment per 5 retros, kept or reverted), `factory:recap` (under 15 line digest); `docs/factory/LESSONS.md` and `docs/factory/experiments.md` (#25)
- Factory freeze rule: after #19, #20 and changelog fragments, factory changes are fixes only until Maya Block 1 ships; onboarding and coverage-88 move behind Block 1 (#23)
- CI/CD hardening: parallel format, credo, test (coverage floor 32%), security (mix_audit, sobelow) and docker boot jobs behind one `ci-success` check; strict Content-Security-Policy; `/health/version`; post-deploy smoke check that opens a bug Issue (#22)
- `factory:pause`, `factory:resume` and `factory:cleanup` skills; `next-task` ranks `paused` Issues (#21)
- OpenSpec changes `ci-cd-hardening`, `factory-flywheel` (retro, improve, recap) and `pokemon-welcome-page`; `.claude/worktrees/` ignored (#17)
- Factory station skills `factory:plan`, `factory:build`, `factory:test`, `factory:review`: ordered, gated wrappers over the existing skills; "Skills by station" in FACTORY.md (#15)
- `quiz-me` skill: on-demand 5 question quiz on recent PRs, specs and ADRs, code structure and factory ops, with spaced repetition borrowed from coding-tutor (#14)
- OpenSpec change `hello-page-says-maya`: Maya landing page, the factory dry run (#12)
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
- Post-deploy smoke check runs every 15 minutes instead of on push, so it can no longer deadlock Render's checksPass deploys; it keeps one open bug Issue per commit and always exits 0 (#28)
- App refuses to boot when `SECRET_KEY_BASE` is under 64 bytes, so a bad key fails the deploy instead of serving 500s (#8)

### Changed
- Welcome page hero shows more of the sea: the frosted panel sits at the top, smaller and more transparent, above a band of open waves (#30)
- Voice outage shows Answers as text; the browser Web Speech fallback moved to PHASE_2.md (#27)
- `factory:build` reads `docs/factory/LESSONS.md` at step 4 and runs `factory:retro` at step 11; the daily digest is `factory:recap` (#25)
- Changelog entries are per-PR fragments in `changelog.d/`, folded into CHANGELOG.md by release-manager, so PRs no longer conflict on the changelog (#23)
- Home page is a minimal Maya landing page (heading, tagline, title "Maya"); generator content removed. Factory dry run; spec `openspec/specs/landing-page/` (#16)
- Plan station: one OpenSpec change and one GitHub Issue per block; builders archive the change in their PR. Matt `to-spec` and `to-tickets` retired (#11)
- Telegram bot and watcher (F4) moved to PHASE_2.md (#10)
- Superpowers SessionStart hook kept in every pane, planner included; intake invokes `grill-with-docs` explicitly (#10)
- Skill names updated to the current Matt Pocock set: `to-spec` and `to-tickets` replace `to-prd` and `to-issues` (#9)
- Supabase project recorded as Ireland (eu-west-1); `DATABASE_URL` pitfalls (API URL, direct host, port 6543) and a local connection test documented (#7)
- Supabase CA certificate shipped in `priv/certs/` instead of the `DATABASE_CA_CERT` env var (#5)
- Prod database connects to Supabase with verified SSL; LiveView host falls back to `RENDER_EXTERNAL_HOSTNAME` (#4)
- Project name written as "Maya", never all caps, across docs and skills (#2)

[Unreleased]: https://github.com/darth-dodo/maya/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/darth-dodo/maya/releases/tag/v0.1.0
