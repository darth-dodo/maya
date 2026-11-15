# Proposal

## Why

Maya is built by an agent-run software factory (ADR-001), and that is half of what makes it a portfolio piece. Today the factory is only visible in FACTORY.md and `docs/factory/`. A public `/factory` page tells the story for visitors, with every number taken from the repo, including the ones that do not flatter it.

## What Changes

- New public page `/factory` (no login, indexable, no LiveView), in the Calm Emerald identity, reusing the homepage footer.
- Stations: plan, build, test, review, each with what it does and its "done when".
- Independent gates: CI (`ci-success`), the production probe (E3, the hourly real Question), and the CI spoiler gate (#40), named as planned until its CI job exists.
- The flywheel: retros, experiments E1 to E3 with their real baseline, target and status from `docs/factory/experiments.md`, and the review reward function with its honest backfill (low precision; 2 of 3 escaped defects not flagged by any finding).
- The build first commits the review backfill numbers to `docs/factory/experiments.md`, since the raw metrics live outside the repo (`~/maya-factory/metrics.csv`); the page cites only numbers in the repo.
- Links to FACTORY.md and the Elixir and Phoenix in 5 minutes explainer on GitHub.

Depends on: the `homepage` change (public pipeline, footer component, per-page robots, `robots.txt` that allows `/factory`). Build after it merges.

Out of scope: live metrics or charts read from GitHub at runtime, a tech stack section (the explainer link covers it), any login. New ideas go to PHASE_2.md.

GitHub Issue: added once it exists.

## Capabilities

### New Capabilities
- `factory-page`: the public `/factory` page that explains the agent-run software factory with numbers from the repo.

### Modified Capabilities
None.

## Impact

- Router: `get "/factory"` in the public browser pipeline; a controller action and template.
- `docs/factory/experiments.md`: a "Review reward backfill" section.
- Tests for the page, including one that checks the page's experiment numbers against `docs/factory/experiments.md`.
- No new dependency, service or host (settled-architecture checked).
