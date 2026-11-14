# Proposal

## Why

The live site still shows the Phoenix generator page. This is the factory dry run: the smallest real change that travels the whole pipeline (OpenSpec change, Issue, builder session, Superpowers TDD, PR, CI, merge, Render deploy, archive) and proves it end to end.

## What Changes

- The home page (`/`) shows a minimal Maya landing page: the heading "Maya" and the line "Maps, Answers, Yaps, Advice. Your spoiler-free Pokemon Emerald companion."
- Phoenix generator content is removed from the home page: marketing copy, the decorative SVG, links to Phoenix docs, GitHub and changelog.
- The browser tab title becomes "Maya", without the " · Phoenix Framework" suffix.
- Out of scope: push-to-talk, LiveView, styling beyond the existing layout and Tailwind defaults, BasicAuth, the `/health` route. New ideas go to `PHASE_2.md`.

## Capabilities

### New Capabilities
- `landing-page`: what a visitor sees at `/` before any Maya feature exists (identity, tagline, no third-party marketing).

### Modified Capabilities
None.

## Impact

- `lib/maya_web/controllers/page_html/home.html.heex`: replaced.
- `lib/maya_web/components/layouts/root.html.heex`: title suffix removed.
- `test/maya_web/controllers/page_controller_test.exs`: asserts the new content instead of the generator text.
- No new dependencies, routes, data or env vars. Render deploys it like any merge to main.
