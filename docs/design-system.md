# Maya Design System

> Living reference for how Maya looks: Calm Emerald by day, Emerald night after dark. The tokens live in `assets/css/app.css` between `/* tokens:start */` and `/* tokens:end */`; this doc mirrors them. Spec: `openspec/specs/design-system/spec.md`. Approved direction: columns A and B of the reference mocks (https://claude.ai/artifact/4P2vNZtmeBLJEAqWDBLEgn), serif headings.

Living reference artifact: [Maya Calm Emerald](https://claude.ai/artifact/PbvRy5EvLwDKb7VY6obsKg), built from this doc and the token layer. Keep its token tables in sync when a value here changes.

---

## 1. Principles

| Principle | Description |
|---|---|
| **Voice first, calm screen** | The screen supports the push-to-talk loop. One action colour, lots of air, nothing competes with the Talk button. |
| **Calm Emerald by day** | Sand and sea green, one deep emerald for actions, a soft single shadow. |
| **Emerald night** | Deep night sea, a thin gold hairline, the ball glows. Made for playing Pokémon Emerald at night. |
| **Tokens only** | Every colour comes from a `--maya-*` token. A test fails on a colour literal anywhere else. |
| **Accessible by default** | WCAG AA: text 4.5:1, state cues 3:1, both themes checked by a test. Reduced motion turns every animation off. |
| **No retro accents** | No pixel font, hard shadows or chunky borders. The ball is the only nod to the games. |

---

## 2. Colour

### 2.1 How themes switch

Day values sit on `:root`. Night values apply on `:root[data-theme="dark"]` (the theme script in `root.html.heex` sets it) and on `:root:not([data-theme="light"])` inside `@media (prefers-color-scheme: dark)` (no JavaScript). Both night blocks hold the same values.

### 2.2 Colour tokens

| Token | Role | Day | Night |
|---|---|---|---|
| `--maya-bg` | page background | `#f6f1e7` sand | `#08181a` night sea |
| `--maya-sea` | scene wash, Maya bubble base | `#e7f3ee` | `#0c2620` |
| `--maya-sea-deep` | the deepest wash at the bottom of the Talk scene, hero and art | `#cfe7df` | `#08181a` |
| `--maya-surface` | cards | `#ffffff` | `#102d24` |
| `--maya-ink` | body text | `#13261f` | `#e8f3ed` |
| `--maya-muted` | secondary text, captions | `#3f6b5b` | `#a6c3b6` |
| `--maya-heading` | hero title and section headings (deep emerald by day, ink at night) | `#0f5a3a` | `#e8f3ed` |
| `--maya-action` | the one action colour: buttons and links (headings use `--maya-heading`) | `#0f5a3a` deep emerald | `#157a48` |
| `--maya-action-ink` | text on action | `#ffffff` | `#ffffff` |
| `--maya-line` | decorative dividers | `rgb(15 58 40 / 0.12)` | `rgb(255 255 255 / 0.08)` |
| `--maya-hairline` | the gold hairline, night only | `transparent` | `#b58a2a` |
| `--maya-accent` | eyebrows and badge text | `#3f6b5b` | `#c9a24a` |
| `--maya-listen` | recording (coral) | `#c24a2e` | `#ef7a5a` |
| `--maya-wait` | uploading and waiting (gold) | `#9a7420` | `#b58a2a` |
| `--maya-success` | success | `#1d7a4a` | `#3fc283` |
| `--maya-error` | error | `#b3261e` | `#f2b8b5` |
| `--maya-glow` | the ball's glow | `none` | `0 0 22px 2px rgb(63 194 131 / 0.35)` |

### 2.3 The ball

Maya's mark keeps its colours in both themes.

| Token | Value |
|---|---|
| `--maya-ball-green` | `#1d9a5b` |
| `--maya-ball-green-dark` | `#0f6b3d` |
| `--maya-ball-green-light` | `#3fc283` |
| `--maya-ball-white` | `#f8f8f8` |
| `--maya-ball-black` | `#1a1a1a` |

### 2.3a Pokémon types

The Gen 3 type chips and dots on the trainer card, the same in both themes, darkened so white chip text (`--maya-action-ink`) stays at least 4.5:1 (lowest: ice, 4.71). The test checks every one.

| Token | Value | Token | Value |
|---|---|---|---|
| `--maya-type-normal` | `#6d6d4e` | `--maya-type-flying` | `#5e55b5` |
| `--maya-type-fire` | `#b4420f` | `--maya-type-psychic` | `#c2185b` |
| `--maya-type-water` | `#2f6fc0` | `--maya-type-bug` | `#66771a` |
| `--maya-type-grass` | `#3f7d23` | `--maya-type-rock` | `#7d6a2a` |
| `--maya-type-electric` | `#8a6a00` | `--maya-type-ghost` | `#574079` |
| `--maya-type-ice` | `#2f7f7f` | `--maya-type-dragon` | `#5531c9` |
| `--maya-type-fighting` | `#a3261f` | `--maya-type-dark` | `#4d3e33` |
| `--maya-type-poison` | `#823d82` | `--maya-type-steel` | `#5c5c78` |
| `--maya-type-ground` | `#85662b` | | |

### 2.4 daisyUI mapping

Both daisyUI themes keep their names (`light` default, `dark` for a dark preference) and read the tokens with `var()`, so `primary` is emerald and no Phoenix purple is left. daisyUI 5.5 accepts `var()` in its theme plugin; the literal fallback was not needed.

| daisyUI | Token |
|---|---|
| `base-100` / `base-200` / `base-300` | `--maya-bg` / `--maya-sea` / `--maya-surface` |
| `base-content`, `neutral` | `--maya-ink` |
| `primary`, `info` | `--maya-action` (content `--maya-action-ink`) |
| `secondary` | `--maya-muted` |
| `accent` | `--maya-accent` |
| `success`, `warning`, `error` | `--maya-success`, `--maya-wait`, `--maya-error` |
| radii (selector, field, box) | `--maya-radius-sm` |

### 2.5 Contrast pairs

WCAG 2.x relative luminance. Text needs 4.5:1, a non-text cue that is the only signal for a state needs 3:1. `test/maya_web/design_tokens_test.exs` recomputes every pair below from `app.css` and fails under the floor. "Scene" is the deepest Talk scene wash: `#cfe7df` by day, `--maya-surface` at night.

| Pair | Kind | Day | Night |
|---|---|---|---|
| ink on bg | text | 14.08 | 15.98 |
| ink on surface | text | 15.85 | 12.98 |
| muted on bg | text | 5.38 | 9.61 |
| muted on scene | text | 4.66 | 7.80 |
| accent on bg | text | 5.38 | 7.57 |
| accent on surface | text | 6.06 | 6.15 |
| success on bg | text | 4.74 | 8.01 |
| error on bg | text | 5.81 | 10.64 |
| action-ink on action | text | 8.26 | 5.37 |
| listen on scene (ring) | non-text | 3.74 | 5.34 |
| wait on scene (ring) | non-text | 3.30 | 4.66 |
| heading on bg | text | 7.33 | 15.98 |
| heading on sea (hero) | text | 7.25 | 14.06 |
| ink on sea (Maya bubble) | text | 13.93 | 14.06 |
| muted on sea-deep | text | 4.66 | 9.61 |
| error on sea-deep ("voice is down") | text | 5.03 | 10.64 |
| surface on listen (Talk button, recording) | text | 4.87 | 5.34 |
| surface on muted (Talk button, waiting) | text | 6.06 | 7.80 |
| surface on success (Talk button, speaking) | text | 5.34 | 6.51 |
| listen ring on the card (surface) | non-text | 4.87 | 5.34 |
| wait ring on the card (surface) | non-text | 4.29 | 4.66 |
| success ring on the card (surface) | non-text | 5.34 | 6.51 |
| "Yes, start fresh" (`btn-error`): content on error | text | 6.54 | 10.64 |

`--maya-line` is decorative (dividers next to text that already has contrast) and is exempt from 3:1. A border that is the only cue for a control uses `--maya-action` or `--maya-muted`.

The Talk header (tide-talk) lays a `--maya-bg` scrim of 85% (`color-mix()`, no literal) over `tide.jpg` by day and `night.jpg` at night, so its text sits on bg, not surface. Worst pixel of the real art at 375px: muted and accent 4.64 by day, muted 7.63 and accent 6.01 at night; rings (non-text) at least 3.29. Never lower the scrim below 85%. The chat is unboxed: older turns are `--maya-muted` on bg, the latest Answer `--maya-ink`, with a `--maya-line` hairline between turns.

The Talk button's state labels use `--maya-surface` as their text colour: white by day, the night card green at night, which keeps every state at 4.5:1 on its state colour. The "Yes, start fresh" button is `btn-error` (it was `btn-warning`, 4.29:1 by day).

---

## 3. Typography

### 3.1 Fonts

| Role | Token | Stack |
|---|---|---|
| Headings and big moments (`h1` to `h4`) | `--maya-font-head` | `"Fraunces", Georgia, serif` |
| Answers, buttons, labels, body | `--maya-font-body` | `"Inter", system-ui, sans-serif` |

Both are self-hosted variable woff2 files, Latin subset (covers the é in Pokémon), with `font-display: swap`. Only Inter is preloaded (one `<link rel="preload">` in `root.html.heex`); Fraunces swaps in. The CSP stays `font-src 'self'`.

| File (`priv/static/fonts/`) | Size | Family and version | Licence | Source |
|---|---|---|---|---|
| `inter-latin-wght-normal.woff2` | 48 KB | Inter, `@fontsource-variable/inter` 5.3.0 | SIL Open Font License 1.1, `OFL-Inter.txt` (The Inter Project Authors) | https://registry.npmjs.org/@fontsource-variable/inter/-/inter-5.3.0.tgz |
| `fraunces-latin-wght-normal.woff2` | 36 KB | Fraunces, `@fontsource-variable/fraunces` 5.3.0 | SIL Open Font License 1.1, `OFL-Fraunces.txt` (The Fraunces Project Authors) | https://registry.npmjs.org/@fontsource-variable/fraunces/-/fraunces-5.3.0.tgz |

Fetched once with `npm pack` (not in `package.json`). Upstream projects: https://github.com/rsms/inter and https://github.com/undercasetype/Fraunces. In production `mix phx.digest` rewrites the `url()` to the digested name with `?vsn=d`, and Plug.Static answers with `cache-control: public, max-age=31536000, immutable`.

### 3.2 Type scale

A 1.25 ratio from a 1rem base. Body line height 1.5, headings 1.1. No text under 0.75rem.

| Token | Size |
|---|---|
| `--maya-text-xs` | 0.75rem |
| `--maya-text-sm` | 0.875rem |
| `--maya-text-base` | 1rem |
| `--maya-text-lg` | 1.25rem |
| `--maya-text-xl` | 1.563rem |
| `--maya-text-2xl` | 1.953rem |
| `--maya-text-3xl` | 2.441rem |

---

## 4. Shape and depth

| Token | Value | Use |
|---|---|---|
| `--maya-radius-sm` | 0.5rem | fields, small buttons, daisyUI radii |
| `--maya-radius-md` | 1rem | cards, the Talk header |
| `--maya-radius-lg` | 1.5rem | scenes, the hero |
| `--maya-radius-pill` | 999px | the Talk button, chips |
| `--maya-shadow-1` | day `0 14px 26px -20px rgb(15 58 40 / 0.6)`; night `inset 0 1px 1px rgb(255 255 255 / 0.06), 0 18px 30px -22px #000000` | cards |
| `--maya-shadow-2` | day `0 12px 20px -12px rgb(15 58 40 / 0.7)`; night `0 0 24px -6px rgb(63 194 131 / 0.6)` | the Talk button |

Every shadow has a blur; a test fails on a zero blur (hard) shadow.

---

## 5. Motion

| Token | Value |
|---|---|
| `--maya-duration` | 200ms (0ms under reduced motion) |
| `--maya-ease` | `cubic-bezier(0.2, 0.8, 0.2, 1)` |

Every transition uses `--maya-duration` and `--maya-ease`. Looping state animations (ring pulse, spin, glow, sound wave, Poké facts) keep their own period. Under `prefers-reduced-motion: reduce`, `--maya-duration` is 0ms and every animation is `none`.

---

## 6. The colour gate

`test/maya_web/colour_gate_test.exs` reads `assets/css/app.css` and every `.ex` and `.heex` under `lib/maya_web`, and fails on `#` hex, `rgb()`, `rgba()`, `hsl()` or `oklch()` outside the token layer, naming the file and line. The one exception: the two `theme-color` metas in `root.html.heex` (browsers need a literal). The legacy allow list is empty since design-apply, and the test fails if a `legacy-colours` block comes back. Note that `#` followed by three hex digits counts as a literal, so write "Issue 117", not the bare number, in CSS and template comments.

The inline footer art in `layouts.ex` takes its colours from `art-*` classes in `app.css`, so it follows the theme. The brand files outside the gate (`priv/static/images/maya-icon.svg`, `logo.svg`, `docs/assets/hero.svg`, `footer.svg`) are images, so they keep literal colours, but `design_tokens_test.exs` fails on any colour in them that is not a `--maya-*` token value. The PNG icons and `og-image.png` are rendered from those SVGs. The manifest colours are `#0f5a3a` (theme) and `#f6f1e7` (background).

---

## 7. Do and don't

| Do | Don't |
|---|---|
| Use a `--maya-*` token or a daisyUI class for every colour | Write a hex, `rgb()` or `oklch()` outside the token layer |
| One action colour per screen (`--maya-action`) | Add a second accent for buttons |
| Fraunces for headings, Inter for everything a person reads quickly | Use Fraunces for Answers, buttons or labels |
| Soft shadows from the shadow scale | Hard, zero blur shadows or chunky retro borders |
| Use `--maya-duration` and `--maya-ease` for transitions | Hard-code durations, or animate under reduced motion |
| Check a new colour pair here and in the contrast test | Fade text with opacity (it breaks contrast) |
| Keep the gold hairline for night | Show gold lines by day |
