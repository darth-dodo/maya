---
name: factory:improve
description: Use when factory:retro says 5 new retros exist, or when asked to improve the Maya factory from its metrics. Hill climbs: one experiment PR at a time, kept or reverted on the numbers, and folds new lessons into docs/factory/LESSONS.md.
---

# factory:improve

Flywheel step 2 (FACTORY.md "Flywheel"). Inputs: `~/maya-factory/metrics.csv`, `~/maya-factory/retros/*.md`, `docs/factory/experiments.md`, `docs/factory/LESSONS.md`. Every repo change goes through a PR; never edit a skill, allowlist or CI file without one. Never merge.

## When

Run when 5 retros exist that are newer than the last improve run (the last row in `experiments.md`, or the first 5 retros ever). Fewer than 5: stop and say how many are missing.

## 1. Close the running experiment

If `experiments.md` has a `running` row, compare its metric: median over the 5 retros since the experiment PR merged vs the row's `baseline`.

- Improved (moved toward `target`): set status `kept`.
- Not improved: open a revert PR (`git revert` of the experiment's squash commit, title `revert: experiment E<n> ...`) and set status `reverted`.

Record the result in the same PR as step 3, or in its own `chore(factory): close experiment E<n>` PR if there is no new experiment.

## 2. Pick the worst metric

Medians of the last 5 rows vs the 5 before (or vs the first 5 if only 5 exist). Metrics, and which way is better:

| Column | Better |
|---|---|
| `lead_time_h` (and its ratio to `estimate_h`) | lower |
| `first_pass_green` (share of `true`) | higher |
| `ci_red_runs` | lower |
| `gate_reds` | lower |
| `review_blockers` | lower |
| `permission_prompts` | lower |
| `denied_calls` | lower |

`issue`, `pr` and `merged_at` identify rows; they are not scored. Skip a metric that is blank in more than 2 of the 10 rows. The worst metric is the one that moved most in the bad direction, or if none moved, the furthest from its ideal (0, or 100% for `first_pass_green`).

## 3. One experiment PR

- One change only (a skill, `.claude/settings.json` allowlist or CI edit), with a hypothesis: "Allowing `git push` for feature branches cuts `permission_prompts` from 6 to 2."
- Branch `chore/factory-experiment-e<n>`, title `chore(factory): experiment E<n> <change>`.
- Append a row to `docs/factory/experiments.md`: `| E<n> | <change> | <metric> | <baseline median> | <target> | running | #<pr> |`.
- Fold the period's retro lessons into `docs/factory/LESSONS.md` under their station, deduplicated, each citing its PR, under 40 rules (merge or drop the weakest to stay under).
- CHANGELOG line, `factory:test`, `factory:review`, then stop for Abhishek.

## Rules

- Never two `running` experiments at once.
- Never keep an experiment without its 5 follow-up retros.
- A kept change stays; a reverted one is not retried without a new hypothesis.
