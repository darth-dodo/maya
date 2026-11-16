# Tasks

## 1. Skill

- [x] 1.1 Write `.claude/skills/factory-dashboard/SKILL.md` (`name: factory:dashboard`, description starting "Use when"), matching the `factory:*` shape: gather table with one command per source, page order, publish step, never-include list; verify each requirement in `specs/factory-dashboard/spec.md` maps to a line in the skill
- [x] 1.2 Run the skill once on live data and publish the page; paste the URL, the "Needs Abhishek" items and the deploy lag line in the PR; verify `git status --short` shows no dashboard file

## 2. Pointers and docs

- [x] 2.1 `factory:recap` and `next-task` each gain one line naming `factory:dashboard` as the visual version; verify with grep
- [x] 2.2 FACTORY.md "Skills by station" gains a `factory:dashboard` row and CLAUDE.md factory entry points list it; verify `grep -l "factory:dashboard" FACTORY.md CLAUDE.md .claude/skills/factory-recap/SKILL.md .claude/skills/next-task/SKILL.md` prints 4 files
- [x] 2.3 `factory:test` gates green (format, credo, test in CI), each exit code checked; no em or en dashes in changed files

## Workflow follow-up

- Archive the change in the same PR (`openspec-archive-change`).
