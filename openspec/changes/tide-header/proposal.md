# Proposal: tide-header

## Why

After #135 (tide-talk) and #136 (tide-homepage) the homepage, the Talk screen and `/factory` still look like three apps: the header has a bold sans "Maya", an "Open Talk" link only on `/`, and the generator's three-way theme switch in a grey pill. On 2026-11-16 Abhishek approved direction "G Cohesive" from the design canvas. This change is its first half: one shared header and a one-button theme toggle. The second half is `tide-cohesion` (Talk screen without containers, new homepage headline, review fixes), built after this one merges.

## What Changes

- **Shared header** on `/`, `/talk` and `/factory`: the "Maya" wordmark in Fraunces (link to `/`), one text link and the theme toggle, with the same height and padding on every page. The link is "Talk" (to `/talk`) on `/` and `/factory`, and "Home" (to `/`) on `/talk`.
- **BREAKING (spec):** the homepage header link `#header-talk-link` reads "Talk", not "Open Talk", and `/factory` gets it too.
- **Theme toggle** becomes one 44px icon button with no container: a moon by day (switches to night), a sun at night (switches to day). Its accessible name says the action ("Switch to night", "Switch to day"). The first visit follows the phone (`prefers-color-scheme`); a tap stores the choice; no explicit "system" option. The theme is still set before first paint, so there is no flash.
- **Removed:** the three-button system, light and dark switch.

Out of scope: the Talk screen body and the homepage hero (`tide-cohesion`), a menu or more header links, a "system" choice, any new page. New ideas go to `PHASE_2.md`.

## Capabilities

### New Capabilities

- `site-header`: the header every page shares (wordmark, one link, theme toggle) and how the theme choice is made, stored and applied.

### Modified Capabilities

- `landing-page`: the homepage header link reads "Talk" (identity requirement).
- `talk-screen`: the Talk screen header has a "Home" link (Talk heading requirement).

## Impact

- `lib/maya_web/components/layouts.ex` (`app/1` header, `theme_toggle/1`), `lib/maya_web/components/layouts/root.html.heex` (inline theme script), `lib/maya_web/router.ex` (the CSP `sha256` of that script), `assets/css/app.css` (header and toggle rules), the three page templates only if they pass a link choice.
- Tests: `test/maya_web/live/talk_screen_page_test.exs` (the 3 `data-phx-theme` buttons assertion), `page_controller_test.exs`, `factory_page_test.exs`, a new header test.
- No new dependency, route or LiveView socket. Not the voice loop: `talk_hook.js` untouched, no latency change. The header sits on the Talk layout, so the PR carries a `Phone check:` line (E4).
- Issue: filed by `factory:plan` and linked from the spec PR.
