# Proposal: tide-cohesion

## Why

#135 (tide-talk) and #136 (tide-homepage) gave both pages the Tide look, but the Talk screen still sits in containers (an outer rounded sea panel and a trainer card box) while the homepage is full bleed art fading into the page, so the two read as different apps. On 2026-11-16 Abhishek approved direction "G Cohesive" from the design canvas. `tide-header` (the shared header and one-button theme toggle) is the first half; this change is the second: the Talk screen without containers, a new homepage headline, and the open review findings from #135 and #136.

## What Changes

**Talk screen `/talk`**

- **Removed:** the outer rounded scene panel (border, radius, sea gradient) and the trainer card box (radius, scrim panel, gold bottom hairline at night). The page background is full bleed `--maya-bg`.
- The trainer info sits in the same tide art band as the homepage hero, smaller, fading into the page: the Emerald ball (about 60px, same state rings: coral recording, gold waiting, glow speaking) left of the eyebrow "ROUTE 104 · 0 of 8 badges" and "Next gym: Roxanne" in Fraunces, the Team chips below.
- Turns sit on the page between `--maya-line` hairlines, styled like the homepage real turn: every Question small, right aligned and muted; the latest Answer 24px and unboxed.
- The Hold to talk pill stays on the page at the bottom, 72px. Behaviour unchanged, `talk_hook.js` untouched, and the button, the trainer band and the header never change size between moments (#74).

**Homepage `/`**

- **BREAKING (spec):** the `h1` reads "Your Pokédex has a voice now." in Fraunces italic, weight 600, about 52px on a phone (was "Ask out loud. No spoilers." at about 64px). The eyebrow stays "A Pokémon Emerald companion".
- More of the tide art shows: the hero fades at the bottom, as the tide-homepage design said (#136 review F1).

**Review fixes**

- #136 F2: delete the dead demo slot CSS (`.demo-shots`, `.demo-video`, `.demo-transcript-box`) and the unused `.home-catchphrase` class rule. `.home-hero .pokeball` stays: the `/factory` hero still uses it.
- #136 F5: scope `.promise-band` under `.home-tide`.
- #135 F1: a plain `content: "·";` line before `content: "·" / "";` on the eyebrow separator, for Safari before 17.4.

Out of scope: the header and theme toggle (`tide-header`), the Poké facts card and Start fresh styling, the `/factory` page body, new copy beyond the headline, any voice loop or hook change. New ideas go to `PHASE_2.md`.

Build order: start after `tide-header` merges. The landing-page identity delta here already includes its "Talk" link, so archive `tide-header` first.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `landing-page`: new headline text and size, hero art fades at the bottom.
- `talk-screen`: no scene panel or card box, trainer info in the art band, turns styled like the homepage real turn, theme looks without the gold card hairline.

## Impact

- `lib/maya_web/live/talk_live.ex` (render markup only, ids kept), `lib/maya_web/controllers/page_html/home.html.heex` (headline), `assets/css/app.css` (Talk block, homepage block, dead CSS, Safari fallback), `docs/design-system.md` (the Talk scrim rule becomes the art band fade rule), `priv/static/fonts/fraunces-latin-wght-italic.woff2` (the Fraunces italic face from the same OFL package, design decision 4).
- Tests: `talk_screen_page_test.exs`, `page_controller_test.exs`, Playwright computed checks. Talk state, mic and voice loop tests unchanged.
- No new dependency or route. Talk layout is on the E4 phone check list, so the PR carries a `Phone check:` line. The voice loop code is untouched, so per-stage latency is reported once (5 holds) to show no stage moved more than 100 ms.
- Issue: filed by `factory:plan` and linked from the spec PR.
