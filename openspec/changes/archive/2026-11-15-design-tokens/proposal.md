# Proposal: design-tokens

## Why

Maya should feel premium, and today it has no single source of truth for how it looks. `assets/css/app.css` holds about 60 hard-coded colours, and the daisyUI themes are still Phoenix's defaults, so every default component is purple (primary hue 277) in dark mode and orange in light mode. Abhishek approved the "Calm Emerald, elegant" direction on 2026-11-15 ("Let's go"), with reference mocks at https://claude.ai/artifact/4P2vNZtmeBLJEAqWDBLEgn (serif headings, columns A and B).

This change builds the foundation: tokens, fonts, the daisyUI mapping and the rules. `design-apply` then moves every page and asset onto it.

## What Changes

- A token layer at the top of `assets/css/app.css`: about 6 core colour tokens plus semantic ones (listening coral, waiting gold, success, error), each with a day value (Calm Emerald) and a night value (Emerald night), switched by the existing `data-theme` attribute and `prefers-color-scheme`.
- One type scale, one radius scale, one shadow scale, one motion duration and easing, and a gold hairline token that only exists at night.
- Fraunces (headings and big moments) and Inter (Answers, buttons, labels) self-hosted as woff2 under `priv/static/fonts`, served by Plug.Static with long cache headers; licences (SIL OFL 1.1) checked and committed next to the files.
- Both daisyUI themes rewritten to point at the tokens, so daisyUI `primary` is emerald and no default component is purple.
- A CI gate (an ExUnit test) that fails when a colour literal appears outside the token layer.
- `prefers-reduced-motion: reduce` turns every animation and transition off through the shared motion token.
- `docs/design-system.md`: the rules, tokens, contrast pairs, do and don't, in the shape of habla-hermano's `docs/design-system.md`.
- A claude.ai Design System artifact as the living reference, created from the Artifact tool's Design System type; if the builder session cannot create it, the PR records the step for the main session.

No visual change beyond colour and type: layouts, spacing and copy stay as they are. CSP stays unchanged (`font-src 'self'` already allows self-hosted fonts).

Out of scope: new screens or features, retro styling (pixel font, hard shadows, chunky borders), a component library beyond what the pages use, applying the system to every page and asset (that is `design-apply`). New ideas go to PHASE_2.md.

## Capabilities

### New Capabilities

- `design-system`: Maya's visual foundation: colour, type, shape, depth and motion tokens for day and night, self-hosted fonts, the daisyUI mapping, the no-literal-colours gate and the written rules.

### Modified Capabilities

None. CSP (`web-security`) is unchanged on purpose.

## Impact

- `assets/css/app.css` (token layer, daisyUI theme blocks, reduced motion), `priv/static/fonts/` (woff2 plus OFL texts), `lib/maya_web/components/layouts/root.html.heex` (one font preload at most).
- New test under `test/maya_web/` for the colour gate and the font route.
- `docs/design-system.md`, a claude.ai Design System artifact.
- No voice loop, agent or data change. No new dependency: font files are committed, not installed.
- Issue: filed by `factory:plan` and linked from the spec PR.
