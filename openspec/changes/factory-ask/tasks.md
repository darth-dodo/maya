# Tasks

## 1. Skill

- [ ] 1.1 Write `.claude/skills/factory-ask/SKILL.md` (`name: factory:ask`, description starting "Use when"), matching the `factory:*` shape: routing table, creates and never creates per route, allowed questions, decision record, hand-offs, writing rules; verify each requirement in `specs/factory-intake/spec.md` maps to a line in the skill
- [ ] 1.2 Walk every spec scenario (bug with and without evidence, feature, product change, later, experiment, improve pickup, question, paid, yes recorded, ambiguous) through the skill text; paste the route and expected output per scenario in the PR

## 2. Experiments link

- [ ] 2.1 Add a `## Candidates` list (date, change, metric, hypothesis, words) to `docs/factory/experiments.md` below the backfill; verify `mix test test/maya_web/controllers/factory_page_test.exs` passes
- [ ] 2.2 One line in `factory:improve` step 3: prefer a Candidates row whose metric is the worst metric, and remove it from Candidates when opened; verify by reading the step

## 3. Docs

- [ ] 3.1 FACTORY.md: the intake box and the mermaid `idea` arrow name `factory:ask`, and "Skills by station" gains a `factory:ask` row; verify with `grep -n "factory:ask" FACTORY.md`
- [ ] 3.2 CLAUDE.md factory entry points list gains `factory:ask`; verify with grep
- [ ] 3.3 Remove the `factory:idea` line from PHASE_2.md; verify `grep -c "factory:idea" PHASE_2.md` prints 0
- [ ] 3.4 `factory:test` gates green (format, credo, test), each exit code checked; no em or en dashes in changed files

## Workflow follow-up

- Archive the change in the same PR (`openspec-archive-change`).
