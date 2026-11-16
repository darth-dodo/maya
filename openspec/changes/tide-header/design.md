# Design: tide-header

## Context

All three pages already render through `Layouts.app/1` (`lib/maya_web/components/layouts.ex`): `/` and `/factory` as controller views with no LiveView socket, `/talk` as a LiveView. The header there has a bold sans "Maya", an "Open Talk" link behind the `talk_link` attr (homepage only) and `theme_toggle/1`, the Phoenix generator's three buttons that fire `JS.dispatch("phx:set-theme")` with `data-phx-theme` system, light or dark.

The theme script is inline in the `head` of `root.html.heex`. It stores `light` or `dark` in `localStorage["phx:theme"]`, removes the key for system, sets `data-theme` and `data-theme-source` on `html`, follows `prefers-color-scheme` changes while the source is system, and syncs tabs through the `storage` event. The CSP in `lib/maya_web/router.ex` allows that script by `sha256`, so any edit to it changes the hash.

## Goals / Non-Goals

**Goals:** one header component with a per-page link; a one-button toggle that keeps the stored key, the no-flash behaviour and the CSP strict.

**Non-Goals:** the art band under the header and the Talk screen body (`tide-cohesion`); restyling the footer.

## Decisions

1. **Keep `localStorage["phx:theme"]`.** A tap writes `light` or `dark`; no key means follow the phone. Visitors who already chose a theme keep it, and the old "system" state is simply "no key". No new key, no migration.
2. **A plain click listener in the inline head script, not `JS.dispatch`.** The script binds one delegated `click` handler for `#theme-toggle` on `document`, so it works on `/` and `/factory` where no LiveView socket binds `phx-click`. It flips `data-theme`, writes the key and sets `data-theme-source="user"`. The `storage` and `prefers-color-scheme` listeners stay as they are. Alternative: a hook in `app.js`; rejected because `app.js` loads `defer`, so the first tap could land before it runs, and the theme code would live in two files.
3. **Accessible name without script.** The button holds two labelled spans, the moon with visually hidden "Switch to night" and the sun with "Switch to day", and CSS on `:root[data-theme]` shows one and sets the other to `display: none`, so the computed name follows the theme with no extra JS and no stale `aria-label`. Icons are the existing heroicons (`hero-moon`, `hero-sun`) with `aria-hidden`. `data-theme` is always set by the head script before paint, so the `prefers-color-scheme` media fallback is not needed for the label.
4. **One link attr.** Replace `talk_link :boolean` with `link :atom` (`:talk` default, `:home` on `/talk`). Ids: `#header-talk-link`, `#header-home-link`. The header gets `id="site-header"`; its height and padding are fixed in `.site-header` CSS (min-height 3.5rem, padding 0.5rem 1rem) so all pages match.
5. **CSP hash.** After editing the script, compute `sha256` of its exact text (the existing comment in `router.ex` says how) and update `router.ex` in the same commit. The Playwright run checks the console for CSP violations on all three pages.

## Risks / Trade-offs

- [The hash drifts if the script is edited or reformatted] → `test/maya_web/content_security_policy_test.exs` fails until `router.ex` is updated (the router comment says so), and the Playwright console check backs it up.
- [A first-time visitor whose phone is in dark mode taps once, then is pinned to day even after the phone switches back] → accepted by Abhishek's call (no "system" option); clearing site data resets it.
- [Header height differs on `/talk` because the LiveView renders the flash group] → the flash group is outside the header; the "Same header everywhere" Playwright row catches any drift.

## Migration Plan

No data. Stored `light` and `dark` keep working. Rollback is a revert of the PR, including the router hash.
