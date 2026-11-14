# 001: Agent-run software factory

- Status: Accepted
- Date: 2026-11-14

## Why

- One person, one weekend, a voice MVP. Abhishek's time goes to product calls and playing gyms, not typing code.
- Agents ship fast but drift: they skip tests, widen scope, swap the stack, and merge their own work. The pipeline has to make the safe path the default.

## What

Claude Code agents build Maya from PRODUCT.md to a live deploy. Humans write PRODUCT.md, answer agents, and merge. Nothing else is manual.

| Station | Owner |
|---|---|
| Intake, plan, review | Matt Pocock skills (`grill-with-docs`, `to-prd`, `to-issues`, `code-review`) |
| Build, verify | Superpowers (plan, TDD, subagents, verification) |
| Work queue | GitHub Issues, each with a "done when" |
| Check | GitHub Actions: compile with warnings as errors, format, credo, tests |
| Gate | Abhishek merges. Agents never do |
| Ship | Render deploys main after CI passes |
| Runtime | Herdr panes on Abhishek's Mac (`planner`, max 2 `builder-<issue>`) |

## How

1. `planner` turns PRODUCT.md into ARCHITECTURE.md and Issues (`project-manager` skill).
2. A builder takes one Issue (`next-task`), works on its own branch, and opens a PR that meets the definition of done in CLAUDE.md.
3. CI runs. Branch protection on main requires a PR and the `test` check, for admins too, and allows squash merges only, titled by the PR title.
4. Abhishek squash merges. `.claude/settings.json` denies `gh pr merge`, so agents cannot.
5. Render deploys. Failures become new Issues.

Guardrails: frozen stack (`settled-architecture` skill), Conventional Commits and a changelog entry per PR, new ideas to PHASE_2.md, F1 kill switch at 3h.

## Consequences

- Easier: parallel work without merge chaos, every change reviewed by CI and a human, a full audit trail in PRs and CHANGELOG.md.
- Harder: the factory runs only while the Mac is on, and agents block on any permission not pre-approved.
- Check: if F1 runs past 3h, drop the factory and build by hand (FACTORY.md).
