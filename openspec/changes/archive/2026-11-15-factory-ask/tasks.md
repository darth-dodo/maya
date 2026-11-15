# Tasks

## 1. Skill

- [x] 1.1 Write `.claude/skills/factory-ask/SKILL.md` (`name: factory:ask`, description starting "Use when"), matching the `factory:*` shape: routing table, creates and never creates per route, allowed questions, decision record, hand-offs, writing rules; verify each requirement in `specs/factory-intake/spec.md` maps to a line in the skill
- [x] 1.2 Walk every spec scenario (bug with and without evidence, feature, product change, later, experiment, improve pickup, question, paid, yes recorded, ambiguous) through the skill text; paste the route and expected output per scenario in the PR

## 2. Experiments link

- [x] 2.1 Add a `## Candidates` list (date, change, metric, hypothesis, words) to `docs/factory/experiments.md` below the backfill; verify `mix test test/maya_web/controllers/factory_page_test.exs` passes
- [x] 2.2 One line in `factory:improve` step 3: prefer a Candidates row whose metric is the worst metric, and remove it from Candidates when opened; verify by reading the step

## 3. Docs

- [x] 3.1 FACTORY.md: the intake box and the mermaid `idea` arrow name `factory:ask`, and "Skills by station" gains a `factory:ask` row; verify with `grep -n "factory:ask" FACTORY.md`
- [x] 3.2 CLAUDE.md factory entry points list gains `factory:ask`; verify with grep
- [x] 3.3 Remove the `factory:idea` line from PHASE_2.md; verify `grep -c "factory:idea" PHASE_2.md` prints 0
- [x] 3.4 `factory:test` gates green (format, credo, test), each exit code checked; no em or en dashes in changed files

## Workflow follow-up

- Archive the change in the same PR (`openspec-archive-change`).

## Scenario walkthrough (1.2)

Each spec scenario read against `.claude/skills/factory-ask/SKILL.md`: the route the skill picks, the expected output, and the section that produces it.

| Scenario | Route | Expected output | Skill section |
|---|---|---|---|
| Route announced first | any | `Route`, `Why`, `Next` lines before anything is created | 1 |
| Exactly one route | Ambiguous when two fit | one route only | 1, 2 (Ambiguous row) |
| Smoke check failure | Bug | one `bug` and `ready-for-agent` Issue quoting the run, checkable "done when", the board's estimate field via `project-manager`, prints `factory:build #N`; no spec PR or PHASE_2.md line | 2 (Bug row, route notes), 4 |
| Bug without evidence | Bug, not filed | no Issue; asks for evidence or offers Question with `mix maya.latency` | 2 (route notes), 3 (Bug evidence) |
| New feature | Feature | `settled-architecture`, then `factory:plan <change-id>`; no hand-filed Issue | 2 (Feature row) |
| Product change | Feature | `grill-with-docs` before `factory:plan` | 2 (Feature row) |
| Idea for later | Later | one PHASE_2.md line `- <Idea> (<date>: "<words>")`; no Issue, change or Candidates row | 2 (Later row), 4, 5 |
| Measurable process change | Experiment | one Candidates row with `permission_prompts`; no settings or skill edit | 2 (Experiment row), 4 |
| Improve picks it up | (factory:improve) | candidate becomes the experiment, row removed | `factory-improve` step 3, first bullet |
| Status question | Question | answer citing `factory:recap` or `next-task`, points to `factory:dashboard` (#104); writes nothing | 2 (Question row), 4 |
| Paid service | Gated | names the Voxtral TTS 3 conflict, asks: ADR, PHASE_2.md or drop; nothing created first | 2 (Gated row, route notes), 3 |
| Yes recorded | Gated | hand-off carries the words and date, plan includes the ADR task | 4 (Feature, Gated row) |
| Ambiguous request | Ambiguous | one question: "build now (factory:plan)" or "later (PHASE_2.md)" | 3 (Now or later) |
| Feature decision on the Issue | Feature | comment `Routed by factory:ask on <date>: "<words>"` on #N | 4 |
| Writing rules | any | inclusive language, "Pokémon" with é, no em or en dashes | 6 |
