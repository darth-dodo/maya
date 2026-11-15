# Proposal

GitHub Issue: #105 (Kind factory, Estimate 1h). Asked for by Abhishek on 2026-11-15: "Create a factory ask skill".

## Why

FACTORY.md draws "Idea from Abhishek -> intake", but nothing written decides where a request goes. Today the session that hears it decides, and this session showed the cost: Issues filed by hand that left the spec to the builder, ideas that should have been a PHASE_2.md line, and process tweaks that went straight into a skill. One entry point, `factory:ask`, routes every request the same way and records why. It replaces the parked `factory:idea` line in PHASE_2.md.

## What Changes

- New project skill `factory-ask` (user-facing `factory:ask <request>`), same shape as the other `factory:*` skills: a routing table, what each route creates and never creates, the questions it may ask, how it records the decision, and the hand-off.
- Seven routes: production bug with evidence, feature or block, later idea, factory experiment, question, paid or stack-changing request, ambiguous request.
- It creates at most one thing per request (a `bug` Issue, a PHASE_2.md line, an experiment candidate, or nothing) and hands everything else to the station that owns it: `factory:plan`, `project-manager`, `factory:improve`, `factory:recap`, `next-task`, `settled-architecture`.
- `docs/factory/experiments.md` gains a `## Candidates` list; `factory:improve` step 3 prefers a candidate whose metric is the worst metric.
- Docs: FACTORY.md intake box and "Skills by station" table point to `factory:ask`; CLAUDE.md factory entry points list gains it; the `factory:idea` line leaves PHASE_2.md.

Out of scope: changing `factory:plan`, `factory:build` or `grill-with-docs`; triaging Issues opened by CI or the smoke check (they stay `bug` Issues as today); a Telegram or phone intake (PHASE_2.md). New ideas go to PHASE_2.md.

## Capabilities

### New Capabilities
- `factory-intake`: how a request from Abhishek enters the factory: the routes, what each creates, the questions asked, the decision record and the hand-off.

### Modified Capabilities

None.

## Impact

- New: `.claude/skills/factory-ask/SKILL.md`.
- Changed: `.claude/skills/factory-improve/SKILL.md` (one line in step 3), `docs/factory/experiments.md` (Candidates section), FACTORY.md, CLAUDE.md, PHASE_2.md.
- No app code, no new dependencies, no paid service, nothing outside the frozen stack.
