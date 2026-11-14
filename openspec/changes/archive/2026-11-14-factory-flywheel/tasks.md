# Tasks

## 1. Lessons and experiments docs

- [x] 1.1 Create `docs/factory/LESSONS.md` grouped by station, seeded with this session's lessons (DATABASE_URL pooler URI not API URL, direct host or port 6543; `| tail` hides exit codes; plan creates the Issue before the spec PR; `skillOverrides` ignores plugin skills, use `Skill(skill:...)` deny rules; merge main instead of rebasing, force push is denied; worktrees reuse the db with `docker compose -p maya`; SECRET_KEY_BASE must be 64+ bytes); verify each lesson cites its PR or Issue
- [x] 1.2 Create `docs/factory/experiments.md` with the table header (id, change, metric, baseline, target, status, PRs); verify it renders on GitHub

## 2. Skills

- [x] 2.1 Add `factory:retro` (`.claude/skills/factory-retro/SKILL.md`): metrics row per the design, retro file, one lesson, candidate experiment, local paths under `~/maya-factory/`; verify by running it for #16 and checking `~/maya-factory/metrics.csv` has one complete row
- [x] 2.2 Add `factory:improve` (`.claude/skills/factory-improve/SKILL.md`): runs at 5 new retros, medians last 5 vs previous 5, one experiment PR, keep or revert after the next 5, folds lessons into LESSONS.md; verify the skill text names every metric column and the keep and revert rules
- [x] 2.3 Add `factory:recap` (`.claude/skills/factory-recap/SKILL.md`): merged PRs, open Issues and blockers, last main CI, metric trend, new lessons, gym reminder, under 15 lines, writes nothing; verify by running it once and checking the output length
- [x] 2.4 Update `factory:build`: step 4 reads `docs/factory/LESSONS.md`, step 11 runs `factory:retro`; verify both lines are present

## 3. Docs

- [x] 3.1 FACTORY.md: add the three skills to "Skills by station" and a short "Flywheel" section (retro, improve, recap, where data lives); CLAUDE.md skill list; verify no em or en dashes
- [x] 3.2 Run `factory:test`; verify all gates green

## Workflow follow-up

- Run `openspec-archive-change` for `factory-flywheel` in the same PR (skip_specs: nothing to sync).
- First `factory:improve` runs after 5 retros exist.
