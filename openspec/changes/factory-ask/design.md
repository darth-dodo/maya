# Design

## Context

See proposal.md, Why. Every station already has an owner; what is missing is the switch in front of them. FACTORY.md rule 1 gives intake interviews to `grill-with-docs`, so `factory:ask` routes and never interviews.

## Goals / Non-Goals

Goals: one repeatable routing decision with a record. Non-goals: re-implementing any station; triaging CI or smoke check Issues (they already arrive as `bug` Issues).

## Routing table

| Route | Signal | Creates | Never creates | Hands off to |
|---|---|---|---|---|
| Bug | Production defect with evidence (log line, smoke check run, screenshot, failing request) | One `bug` Issue: evidence, done when, estimate | Spec PR, PHASE_2.md line | `project-manager` (board fields), then `factory:build #N` |
| Feature | New behavior, block or spec change | Nothing itself | A hand-filed Issue | `factory:plan <change>` (`grill-with-docs` first if PRODUCT.md changes) |
| Later | "someday", "after the MVP", or not now | One dated PHASE_2.md line | Issue, OpenSpec change | none |
| Experiment | Factory process change with a measurable hypothesis | One Candidates row in `docs/factory/experiments.md` | Skill, allowlist or CI edit | the next `factory:improve` |
| Question | About code, status or plans | Nothing | Anything | answers; points to `factory:recap`, `factory:dashboard` (#104), `next-task` |
| Gated | Outside the frozen stack, paid service or new dependency | Nothing until Abhishek says yes | Anything before the yes | `settled-architecture`, then `factory:plan` with an ADR task |
| Ambiguous | Fits more than one route, or none | Nothing until answered | Anything before the answer | one routing question, then that route |

## Decisions

- **A router skill, not a new station.** `factory:ask` sits on the "Idea from Abhishek" arrow. Alternative: extend `project-manager` "New ideas". Rejected: project-manager plans the whole board; per-request routing there hides the route table.
- **Creates at most one thing.** A bug Issue, a PHASE_2.md line, a Candidates row, or nothing. Everything else is a hand-off, so each station keeps a single owner.
- **Candidates live in `docs/factory/experiments.md`.** Retro notes sit outside the repo (`~/maya-factory/`), so a candidate there is invisible to other sessions. A `## Candidates` list below the backfill keeps one log. `factory:improve` step 3 gains one line to prefer a matching candidate; without it the route is a dead end.
- **Repo lines ride a docs PR.** A PHASE_2.md line or Candidates row is a repo change, so it goes on a `docs/intake-<yyyy-mm-dd>` branch and PR (reused while open the same day) with a changelog fragment. Per the Later rule those lines get no Issue (see Open Questions).

## Risks / Trade-offs

- [Misroute: a feature filed as a bug] -> the Bug route needs evidence of a production defect; otherwise Ambiguous.
- [Too many questions slow Abhishek down] -> at most two, routing only, with options.
- [The `/factory` page test reads experiments.md] -> Candidates sits below the table and the backfill; the build runs `factory_page_test.exs`.

## Open Questions

- Are intake-line PRs (PHASE_2.md, Candidates) exempt from "every PR gets an Issue"? The design assumes yes, since the Later rule says "no Issue".
