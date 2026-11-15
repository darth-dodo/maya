# Proposal: design-apply

## Why

`design-tokens` gives Maya one design system (Calm Emerald by day, Emerald night), but the pages and assets still carry their own colours: the Talk screen and the homepage are fixed light scenes in both themes, `/factory` mixes daisyUI defaults with local colours, and the README SVGs, icons and og-image were drawn before the palette existed. Abhishek approved applying the system everywhere on 2026-11-15, with reference mocks at https://claude.ai/artifact/4P2vNZtmeBLJEAqWDBLEgn (columns A and B).

## What Changes

- Talk screen (`/talk`): every colour, font, radius, shadow and motion comes from the tokens; it follows the theme instead of staying a fixed light scene, so at night it is the Emerald night look (deep night sea, gold hairline on the trainer card, the ball glows). Fraunces for the heading and the gym line, Inter for Answers, buttons and labels. Only state changes move (ring, card, wave), on the shared duration and easing.
- Homepage (`/`) and `/factory`: the same, both themes.
- The footer SVG in `layouts.ex`: token colours via CSS (`var()` or `currentColor`), no literals.
- `theme-color` metas and the web app manifest colours move to the palette.
- Brand assets redrawn on the palette: `maya-icon.svg`, `logo.svg`, the favicon and app icon PNGs, `og-image.png`, and the README `docs/assets/hero.svg` and `footer.svg`.
- The colour gate allow list from `design-tokens` is emptied, so no literal is left outside the token layer.
- Before and after screenshots of `/`, `/talk` and `/factory` in light and dark at 375 and 1280 px in the PR.

Out of scope: new screens or features, layout or copy changes beyond what the look needs, retro styling (pixel font, hard shadows, chunky borders), a component library beyond what the pages use, a theme switch control. New ideas go to PHASE_2.md.

Depends on `design-tokens` being merged first. No `design.md`: the decisions (token values, gate, fonts, motion) live in `design-tokens/design.md`.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `talk-screen`: follows the design system in day and night.
- `landing-page`: follows the design system in day and night.
- `factory-page`: follows the design system in day and night.
- `site-metadata`: theme colours from the palette; brand assets (icons, og-image, README art) drawn on the palette.

## Impact

- `assets/css/app.css` (per-page blocks rewritten onto tokens), `lib/maya_web/components/layouts.ex` (footer SVG), `lib/maya_web/components/layouts/root.html.heex` (theme-color), `priv/static/manifest.webmanifest`, `priv/static/images/` (icons, og-image, logo), `docs/assets/` (README SVGs), the colour gate test.
- Talk screen markup may gain token classes but no behaviour change: the push-to-talk state machine, mic handling and voice loop are untouched, so no latency numbers change (stated in the PR).
- Issue: filed by `factory:plan` and linked from the spec PR.
