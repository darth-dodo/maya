# Design: tshirt-sizes

## Context

See proposal.md (Why). Estimates live in three places today: the "## Estimate" section of each Issue body (`project-manager` template, `30m | 1h | 2h`), the GitHub Project 1 Estimate field (single select, options 30m, 1h, 2h; field `PVTSSF_lAHOALocAs4Brni8zhp5bwE`), and `estimate_h` in `~/maya-factory/metrics.csv` (`factory:retro`, 30m = 0.5). The cut rule ("Past 2x estimate, take the cut") is in CLAUDE.md, FACTORY.md and `project-manager`.

## Goals / Non-Goals

- Goal: one size per Issue, the same in body and board, and a cut rule anyone can compute from the size.
- Non-goal: rewriting `estimate_h` in old retro rows, or measuring estimate accuracy.

## Decisions

1. **Midpoint hours keep the metric.** `estimate_h` stays and becomes the size midpoint (XS 0.25, S 0.75, M 1.5, L 3). Old rows (0.5, 1, 2) sit inside S, M and L, so lead time against estimate still compares. Alternative: drop `estimate_h` for `size` only; rejected, it breaks every old row.
2. **`size` is appended as the last CSV column.** Old rows get a blank `size`, read as unknown. Alternative: insert after `estimate_h`; rejected, it shifts every old row's columns.
3. **Cut at 2x the upper bound,** not 2x the midpoint: an L at 2x midpoint (6h) would cut work that is still inside a fair L range. L past about 8h.
4. **XL is a planning signal only.** It exists on the board so a planner can mark "too big" while splitting, but `factory:plan` never files it and builders never start it.
5. **Re-size open Issues by judgement, map closed ones mechanically.** Removing a single select option clears that value on every item, closed ones included, so closed items are moved first by the old mapping (30m to S, 1h to M, 2h to L) to keep their history, then the old options go.
6. **Board edits are scripted with `gh project item-edit`,** one command per item (zsh does not word-split). The new options are added through the GraphQL `updateProjectV2Field` mutation, which replaces the option list: send the old and new options together first, and drop the old ones only in the last step.

## Re-size of every open Issue (2026-11-15)

| Issue | Old | New | Reason |
|---|---|---|---|
| #40 Sunday proof | 2h | L | CI spoiler gate, scheduled real-model probe and a phone proof: a whole block |
| #41 Events, Humor dial and guide | 2h | L | Three tools (`log_event` with undo, humor dial, `search_guide`), each tested |
| #49 Plug.BasicAuth on browser pages | 30m | S | One plug in the router pipeline plus tests |
| #56 Rotating catchphrases | 30m | S | One prompt and selection change with a test |
| #64 flaky barge-in test | 30m | XS | Fix one test wait |
| #75 Live transcription (realtime STT) | 2h | XL | Spike, relay, fallback, eval set, ADR and phone checks: over 4h; split before more build (see Open Questions) |
| #82 DB outage shows "voice is down" | 30m | S | One error path and its test |
| #83 Talk button stuck after lost capture | 30m | S | One JS pointer event fix |
| #87 Error monitoring with Sentry | 1h | M | ADR, config, scrubbing with a test, deploy check |
| #89 Trainer card stale after an Event | 30m | S | One PubSub or assign refresh with a test |
| #95 Transcript countdown and edit | 2h | L | Migration, two forms, countdown, latency numbers and phone check |
| #96 TTS playback robustness on iPhone | 2h | L | Watchdog, turn ids, audio session, error bodies and phone checks |
| #104 factory:dashboard skill | 1h | M | A new skill with a page and its checks |
| #105 factory:ask skill | 1h | M | A new routing skill |
| this change's Issue | 1h | S | Docs, skills and a scripted board edit |

## Cross-change note

The `factory-ask` change (branch `spec/factory-ask`, Issue #105) routes requests and mentions estimates. Once this change lands, `factory:ask` must use sizes (and refuse XL the same way `factory:plan` does). Whichever merges second updates that skill; this change does not edit `factory-ask` files.

## Risks / Trade-offs

- [Removing old options clears values on closed items] → move closed items first (Decision 5) and check with `gh project item-list` that none uses 30m, 1h or 2h before removing.
- [Option replacement via GraphQL changes option ids] → read ids back with `gh project field-list` after each mutation; never hard code them in skills.
- [Sizes drift toward "everything is M"] → `factory:improve` can compare `lead_time_h` with the midpoint per size once rows exist.

## Migration Plan

1. Add XS, S, M, L, XL next to the old options.
2. Set every open Issue to its new size (table above) on the board and in its body.
3. Set every closed item by the old mapping.
4. Confirm no item uses an old option, then remove 30m, 1h, 2h.
5. Rollback: re-add the old options and map back (S to 30m, M to 1h, L to 2h).

## Open Questions

- #75 is In Progress and sizes as XL. Proposed split: (a) spike, relay, partials and fallback (L); (b) eval set, `:stt_final` decision, ADR-009 and docs (M). Abhishek decides whether to split now or let the current builder finish as one Issue; it does not change this spec.
