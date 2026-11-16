# Design: tide-cohesion

## Context

On main after #135 and #136 (and after `tide-header`):

- `.talk-screen` (`assets/css/app.css`) is a padded grid with a `--maya-line` border, `--maya-radius-lg` and a `--maya-sea` to `--maya-sea-deep` gradient: the scene panel.
- `.trainer-card` is a sticky grid (ball | meta, Team across) with `--maya-radius-md`, an 85% `--maya-bg` scrim over `--card-art` and a `--maya-hairline` bottom border (gold at night). It is sticky under the status bar (#78, Issue 117) and keeps one height in every moment (#76).
- `.pokeball` is already `--size: 3.75rem` (60px); `.ball-ring` carries the coral, gold and glow states from `#talk-screen[data-state]`.
- `.turn .you` is right aligned at body size; `.turn.now .maya` is `--maya-text-xl` (24px). The homepage `.real-turn-question` is `--maya-text-sm`, muted.
- `.home-tide .home-hero` fades with `linear-gradient(transparent 0, var(--maya-bg) 6.5rem)` over the art, with `padding-top: 7rem`, so only a thin, already fading strip of art shows (#136 review F1).
- `.home-hero .pokeball` (line about 570) still styles the `/factory` hero ball, so it is not dead CSS, unlike the #136 review said. `.home-catchphrase` as a class has no user (the homepage uses it as an id with class `bubble`).

## Goals / Non-Goals

**Goals:** one art band language for both pages; Talk turns that match the homepage real turn; review findings closed.

**Non-Goals:** markup ids or LiveView assigns (all ids stay, so the state and voice tests stay green); `talk_hook.js`; the Poké facts card, Start fresh and the dock position.

## Decisions

1. **One fade recipe.** Define the band background once: `linear-gradient(transparent 0 var(--band-clear), var(--maya-bg) var(--band-solid)) no-repeat, var(--band-art) center top / cover no-repeat, var(--maya-bg)`, with `--band-art` switched per theme as today. The hero sets `--band-clear: 6rem; --band-solid: 9.5rem; padding-top: 10rem` (the F1 fix, keeping the hero under 620px; drop `min-height` if it pushes past). The Talk band sets about `--band-clear: 1.5rem; --band-solid: 3.5rem` and enough top padding that the ball and eyebrow start below `--band-solid`. Text always sits on solid `--maya-bg`, so the existing contrast pairs hold with no new measurement on art. Alternative: keep the 85% scrim on Talk; rejected because it reads as a box, which is what Abhishek asked to drop.
2. **Remove, do not restyle, the containers.** `.talk-screen` loses border, radius, background image and side padding; the band uses `margin-inline: -1rem` like the hero so the art is full bleed inside the `main` gutter. `.trainer-card` loses radius and the hairline border. Keep it sticky (#78): its bottom is solid `--maya-bg`, so the chat never shows through it. If the sticky band is too tall on the phone, the phone check decides (open question 1).
3. **Turns share the real turn rules.** Set `.turn .you` to `--maya-text-sm` and `--maya-muted` for every turn (latest included), so Questions match `#real-turn-question`. Older Answers keep muted body size; the latest Answer keeps 24px ink. Rather than a shared class across pages, the Talk rule uses the same tokens; the Playwright row compares computed sizes across the two pages.
4. **Headline** is a text swap in `home.html.heex` plus `.home-tide .home-heading { font-style: italic; font-weight: 600; font-size: clamp(2.75rem, 14vw, 3.5rem); }` (about 52px at 375). `priv/static/fonts/` has only `fraunces-latin-wght-normal.woff2`, so without more the browser would synthesise a slanted roman, not the Fraunces italic the canvas showed. Add `fraunces-latin-wght-italic.woff2` from the same `@fontsource-variable/fraunces` 5.3.0 tarball (fetched with `npm pack`, not in `package.json`, same OFL file) with a second `@font-face` (`font-style: italic`, same `unicode-range`), not preloaded, and list it in the fonts table of `docs/design-system.md`. A font file is not a dependency and the CSP stays `font-src 'self'`. Alternative: synthesised italic, zero bytes but visibly rough at 52px; Abhishek can pick it instead (open question 2).
5. **Review fixes** are CSS only: delete `.demo-shots`, `.demo-shots figure`, `.demo-shots img`, `.demo-video`, `.demo-transcript-box*` and `.home-catchphrase`; keep `.home-hero .pokeball`; rename `.promise-band` selectors to `.home-tide .promise-band`; add `content: "·";` before `content: "·" / "";`.

## Risks / Trade-offs

- [A sticky band with art is taller than the old slim card, leaving less room for turns on a small phone] → band height capped by the "shorter than the hero" scenario, measured at 375 by 667; phone check decides.
- [Removing the scene panel padding changes the Talk button's position under the thumb] → the "Pill size" and "Nothing changes size between moments" rows, plus the phone check.
- [The italic woff2 adds about 40 KB on `/`] → it loads only where italic Fraunces is used (the headline), with `font-display: swap`, and is cached for a year.
- [Old tests assert the gold card hairline or the scrim] → those assertions change with the modified scenarios; state, mic and voice assertions do not.

## Migration Plan

CSS and template only. Rollback is a revert of the PR.

## Open Questions

1. Keep the trainer band sticky (#78) now that it carries art? Default yes; Abhishek can switch it to scroll away at the phone check without a spec change.
2. Real Fraunces italic woff2 (default, decision 4) or the synthesised italic? Only task 3.1 changes if he picks synthesised.
3. Eyebrow copy: keep "A Pokémon Emerald companion" (default) or switch to "A spoiler-free Pokémon Emerald companion"? A one-line spec and test edit if he switches.
