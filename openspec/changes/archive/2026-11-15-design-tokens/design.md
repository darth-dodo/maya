# Design: design-tokens

## Context

See proposal.md, Why. Today `assets/css/app.css` has two Phoenix default daisyUI theme blocks (purple primary) and per-page blocks (`.talk-screen`, home, factory) that define their own local colour variables. The root layout already sets `data-theme` from `localStorage` or `prefers-color-scheme`. `MayaWeb.static_paths/0` already includes `fonts`, and the CSP already has `font-src 'self'`.

The approved look comes from the mock source `maya-directions.html` (columns A Calm Emerald and B Emerald night, serif headings). The values below start from it and are nudged only where a contrast pair failed.

## Goals / Non-Goals

Goals: one token layer that every later rule reads; daisyUI follows it; fonts load from self; a gate keeps literals out.

Non-goals: moving page layouts onto the tokens (that is `design-apply`, which also removes the local per-page colour variables), new components.

## Decisions

### Token names and values

All tokens are prefixed `--maya-`. Day is the default on `:root`; night applies on `:root[data-theme="dark"]` and on `:root:not([data-theme="light"])` inside `@media (prefers-color-scheme: dark)`, matching the existing theme script.

| Token | Role | Day | Night |
|---|---|---|---|
| `--maya-bg` | page background | `#f6f1e7` sand | `#08181a` night sea |
| `--maya-sea` | scene wash, Maya bubble base | `#e7f3ee` | `#0c2620` |
| `--maya-surface` | cards | `#ffffff` | `#102d24` |
| `--maya-ink` | body text | `#13261f` | `#e8f3ed` |
| `--maya-muted` | secondary text, captions | `#3f6b5b` | `#a6c3b6` |
| `--maya-action` | the one action colour (buttons, links, headings in day) | `#0f5a3a` deep emerald | `#157a48` |
| `--maya-action-ink` | text on action | `#ffffff` | `#ffffff` |
| `--maya-line` | dividers and borders | `rgb(15 58 40 / 0.12)` | `rgb(255 255 255 / 0.08)` |
| `--maya-hairline` | the gold hairline (night only) | `transparent` | `#b58a2a` |
| `--maya-accent` | eyebrows and badges text at night | `#3f6b5b` | `#c9a24a` |
| `--maya-listen` | recording (coral) | `#c24a2e` | `#ef7a5a` |
| `--maya-wait` | uploading and waiting (gold) | `#9a7420` | `#b58a2a` |
| `--maya-success` | success | `#1d7a4a` | `#3fc283` |
| `--maya-error` | error | `#b3261e` | `#f2b8b5` |
| `--maya-glow` | the ball's glow | `none` | `0 0 22px 2px rgb(63 194 131 / 0.35)` |

Ball colours (`#1d9a5b`, `#0f6b3d`, `#3fc283`, `#f8f8f8`, `#1a1a1a`) become `--maya-ball-*` tokens with the same value in both themes: the ball is Maya's mark and does not change at night.

Contrast pairs (WCAG 2.x relative luminance, computed 2026-11-15; text needs 4.5:1, non-text 3:1):

| Pair | Day | Night |
|---|---|---|
| ink on bg | 14.08 | 15.98 |
| ink on surface | 15.85 | 12.98 |
| muted on bg | 5.38 | 9.61 |
| muted on deepest scene wash (`#cfe7df` day, surface night) | 4.66 | 7.80 |
| action-ink on action | 8.26 | 5.37 |
| action on bg (day headings) | 7.33 | n/a |
| accent on bg / surface (night) | n/a | 7.57 / 6.15 |
| error on bg (text) | 5.81 | 10.64 |
| success on bg (text) | 4.74 | 8.01 |
| listen on scene (non-text, ring) | 3.74 on `#cfe7df` | 6.58 |
| wait on scene (non-text, ring) | 3.30 on `#cfe7df` | 5.74 |

Changes from the mock, and why: night action `#1d9a5b` gave white text only 3.6:1, so the night action base is `#157a48` (the gradient may still end at `#0f5a3a`); day coral `#d9573a` and gold `#b58a2a` fell under 3:1 on the scene wash, so day uses `#c24a2e` and `#9a7420`. `--maya-line` is decorative (dividers next to text that already has contrast), so it is exempt from 3:1; any border that is the only cue for a control uses `--maya-action` or `--maya-muted` instead.

### Type, shape, depth, motion

- `--maya-font-head: "Fraunces", Georgia, serif`; `--maya-font-body: "Inter", system-ui, sans-serif`.
- One type scale on a 1.25 ratio from a 1rem base: `--maya-text-xs` 0.75rem, `-sm` 0.875rem, `-base` 1rem, `-lg` 1.25rem, `-xl` 1.563rem, `-2xl` 1.953rem, `-3xl` 2.441rem. Body line height 1.5, headings 1.1. No text under 0.75rem.
- Radius: `--maya-radius-sm` 0.5rem, `-md` 1rem, `-lg` 1.5rem, `-pill` 999px.
- Shadow: `--maya-shadow-1` (cards) day `0 14px 26px -20px rgb(15 58 40 / 0.6)`, night `inset 0 1px 0 rgb(255 255 255 / 0.06), 0 18px 30px -22px #000`; `--maya-shadow-2` (the Talk button) day `0 12px 20px -12px rgb(15 58 40 / 0.7)`, night `0 0 24px -6px rgb(63 194 131 / 0.6)`. No hard (zero blur) shadows.
- Motion: `--maya-duration` 200ms and `--maya-ease` `cubic-bezier(0.2, 0.8, 0.2, 1)` for every transition. Looping state animations (ring pulse, spin, glow, wave) keep their own period but use `--maya-ease` where they ease. Under `prefers-reduced-motion: reduce`, `--maya-duration` is `0ms` and every `animation` is `none`; the existing reduced motion block is extended, not duplicated.

### daisyUI mapping

Both daisyUI theme blocks keep their names (`light` default, `dark` prefersdark) so `data-theme` keeps working, and their colours become `var(--maya-*)`: `base-100` bg, `base-200` sea, `base-300` surface, `base-content` ink, `primary` action, `primary-content` action-ink, `secondary` and `accent` muted or accent, `neutral` ink, `success`, `warning` wait, `error`, `info` action. Radii map to the radius scale.

Alternative considered: literal values inside the daisyUI blocks. Rejected as the default because it duplicates every value; it is the fallback if daisyUI's theme plugin does not accept `var()` values (see Risks). Either way the blocks sit inside the token layer.

### Token layer and the gate

The token layer is the part of `app.css` between `/* tokens:start */` and `/* tokens:end */`, holding the `--maya-*` definitions and both daisyUI theme blocks. A new ExUnit test reads `assets/css/app.css` and every `.ex` and `.heex` under `lib/maya_web`, and fails on any colour literal (`#rgb`, `#rrggbb`, `#rrggbbaa`, `rgb(`, `rgba(`, `hsl(`, `oklch(`) outside the token layer. Allowed exceptions, listed in the test by file: the `theme-color` metas in `root.html.heex` (browsers need a literal). `priv/static` files (SVG, manifest) are outside the gate; `design-apply` handles them by hand. A test fits CI with no new step, unlike a shell grep.

During `design-tokens` the per-page blocks still hold literals, so the gate starts with those blocks on an explicit allow list that `design-apply` empties. The test prints the remaining count, so the allow list cannot grow silently.

### Fonts

- Files: `fraunces-latin-wght-normal.woff2` (variable, weights 600 to 800 used) and `inter-latin-wght-normal.woff2` (variable, 400 to 700 used), Latin subset, from the Fontsource packages (`@fontsource-variable/fraunces`, `@fontsource-variable/inter`) fetched once with `npm pack` into the scratchpad and copied in. Not added to `package.json`: the files are committed.
- Licences: both are SIL Open Font License 1.1 (Fraunces: Undercase Type; Inter: Rasmus Andersson). The builder confirms each from the package's `LICENSE` and commits it as `priv/static/fonts/OFL-Fraunces.txt` and `OFL-Inter.txt`; `docs/design-system.md` records name, version, licence and source URL.
- `@font-face` in the token layer with `font-display: swap` and `src: url("/fonts/...")`. `mix phx.digest` rewrites `url()` in the built CSS to the digested name with `?vsn=d`, and Plug.Static then sends `cache-control: public, max-age=31536000, immutable`. A test asserts the font route answers 200 with `font/woff2`; the cache header is checked on a prod build (`MIX_ENV=prod mix assets.deploy` then a request against the digested path) and pasted in the PR.
- At most one `<link rel="preload" as="font" type="font/woff2" crossorigin>` for Inter in `root.html.heex`; CSP unchanged.

### docs/design-system.md and the artifact

`docs/design-system.md` follows habla-hermano's (`git -C /Users/abhishek/stuff/ai-adventures/habla-hermano show origin/main:docs/design-system.md`): principles, tokens table (day and night), type scale, shape, depth, motion, contrast pairs, do and don't, fonts and licences. The claude.ai Design System artifact mirrors the same tokens as a living reference and is linked from the doc. If the builder cannot create it, the PR body says so and lists the step for the main session.

## Risks / Trade-offs

- [daisyUI theme plugin may need literal colours, for example to compute `color-mix`] → try `var()` first and check one daisyUI button in both themes; if it breaks, write literals in the theme blocks (still inside the token layer).
- [Fraunces is a large variable font] → Latin subset only, one file, `font-display: swap`; check its size (target under 120 KB) and note it in the PR.
- [Flash of fallback font on first visit] → swap plus Georgia and system-ui fallbacks; acceptable for a voice-first app.
- [Gate false positives, for example `#` in an anchor href] → the regex only matches colour-shaped tokens; anchors like `#talk` have non-hex letters or wrong length, and the test lists any hit with file and line.

## Migration Plan

One PR. Rollback is a revert: no data, no runtime state.
