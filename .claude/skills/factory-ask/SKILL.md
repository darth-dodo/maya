---
name: factory:ask
description: Use when Abhishek brings any request, idea, bug or question to the Maya factory (`factory:ask <request>`). Routes it to exactly one route, creates at most one thing, records the decision with the date and his words, and hands off to the station that owns the rest.
---

# factory:ask

The intake switch on FACTORY.md's "Idea from Abhishek" arrow. It routes; it never interviews (that is `grill-with-docs` and `openspec-propose`) and never re-implements a station. Invoke named skills with the Skill tool; do not copy their content. Never merge.

## 1. Announce the route first

Before creating any file, Issue, line or comment, print three lines:

```
Route: <Bug | Feature | Later | Experiment | Question | Gated | Ambiguous>
Why: <one line>
Next: <the next command, e.g. factory:plan <change-id>, or for Bug "file the bug Issue, then factory:build #<new>">
```

The Bug route prints the real `factory:build #N` once the Issue exists.

Pick exactly one route from the table. A request that fits two routes, or none, is Ambiguous.

## 2. Routing table

| Route | Signal | Creates | Never creates | Hands off to |
|---|---|---|---|---|
| Bug | Production defect with evidence: a log line, smoke check run, screenshot or failing request | One GitHub Issue labelled `bug` and `ready-for-agent`: the evidence (quoted or linked), a "done when", an estimate, out of scope; no spec PR | OpenSpec change, spec PR, PHASE_2.md line | `project-manager` (board fields), then print `factory:build #N` |
| Feature | New behavior, block or spec change | Nothing itself | A hand-filed Issue; a spec left to the builder | `settled-architecture` (stack check), then `factory:plan <change-id>` with a proposed change id; `grill-with-docs` first if it changes PRODUCT.md (who Maya is for, or what PRODUCT.md promises) |
| Later | "later", "someday", "after the MVP", or Abhishek picks not now | One PHASE_2.md line | Issue, OpenSpec change, Candidates row | none |
| Experiment | Factory process change with a measurable hypothesis (a metric from `~/maya-factory/metrics.csv`) | One row in `## Candidates` of `docs/factory/experiments.md` | Any skill, `.claude/settings.json` allowlist or CI edit | the next `factory:improve` (step 3 reads Candidates) |
| Question | About the code, status or plans | Nothing | Any Issue, comment, file or line | Answer in the session, citing `factory:recap` or `next-task` output; point to `factory:dashboard` (#104) for a visual view |
| Gated | Needs something outside the frozen stack, a paid service or a new dependency | Nothing until Abhishek says yes | Anything before the yes | `settled-architecture` names the conflict, then ask; yes: `factory:plan` with an ADR task in `docs/adr/`; no: offer Later |
| Ambiguous | Fits more than one route, or none | Nothing until answered | Anything before the answer | One routing question (section 3), then that route |

Route notes:

- Bug without evidence ("I think voice is slow sometimes"): create nothing. Ask for a log, run or screenshot, or offer the Question route with `mix maya.latency`.
- Bug estimate: a size from the `project-manager` table (XS to L); `project-manager` also sets Kind, Estimate (the same size) and Status on Project 1, and a milestone when the defect belongs to a block. A bug sized XL is not filed: propose a split into Issues of L or smaller, as `factory:plan` does.
- Bug "done when" is checkable, e.g. "the smoke check is green twice in a row".
- Experiment without a metric: take the Ambiguous route and ask which metric it should move.
- Gated example: "use ElevenLabs for a nicer voice" conflicts with the settled TTS (Voxtral TTS 3) and is another, paid vendor. Ask: plan it with an ADR, park it in PHASE_2.md, or drop it.
- Issues opened by CI or the smoke check are already `bug` Issues; do not re-triage them.

## 3. The only questions allowed

Ask only a question whose answer changes the route, at most two per request, with AskUserQuestion and options when the answers are a short list:

| Decider | Options |
|---|---|
| Now or later | "build now (factory:plan)", "later (PHASE_2.md)" |
| Gated approval | "plan it with an ADR", "park it in PHASE_2.md", "drop it" |
| Which block or milestone | the open milestones from `gh api repos/darth-dodo/maya/milestones` |
| Which metric | the `metrics.csv` columns listed in `factory:improve` step 2 |
| Bug evidence | "here is the evidence", "answer it as a Question" |

Never ask about requirements, wording or design; that belongs to `grill-with-docs` and `openspec-propose`.

## 4. Record the decision

Every route that creates something records the date (today, `YYYY-MM-DD`) and Abhishek's words, quoted:

| Route | Where |
|---|---|
| Bug | The Issue body: `Routed by factory:ask on <date>: "<words>"` |
| Feature, Gated | Pass the date and the words in the `factory:plan` hand-off; once it creates Issue #N, comment on #N: `Routed by factory:ask on <date>: "<words>"` (Gated adds the yes, e.g. `"yes, plan it"`, and the plan includes the ADR task) |
| Later | The PHASE_2.md line: `- <Idea> (<date>: "<words>")` |
| Experiment | The Candidates row: `\| <date> \| <change> \| <metric> \| <hypothesis> \| "<words>" \|` |

Question and Ambiguous (before the answer) record nothing.

## 5. Repo edits

A PHASE_2.md line or Candidates row is a repo change. Decided by Abhishek on 2026-11-15 (#106): it needs no Issue, and it rides along in the next related open PR where one exists. Only when none exists: branch `docs/intake-<yyyy-mm-dd>` from `origin/main` (reuse it while its PR is open the same day), conventional commit (`docs: ...`), changelog fragment in `changelog.d/`, PR. Never edit `CHANGELOG.md`, never push to `main`, never merge.

## 6. Writing rules

Every line, Issue and comment: inclusive language, "Pokémon" with é, "Maya" never all caps, no em or en dashes.
