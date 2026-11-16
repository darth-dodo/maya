# Tasks

Start from main (after #135 and #136, merged 2026-11-16). Build with Superpowers TDD. Ships before `tide-cohesion`.

## 1. Baseline

- [x] 1.1 Before screenshots of `/`, `/talk` and `/factory` at 375px in light and dark (Playwright, `data-theme` set per shot), saved outside the repo for the PR; verify 6 images exist

## 2. Shared header

- [x] 2.1 Tests first: header parts and per-page link (`#header-talk-link` "Talk" on `/` and `/factory`, `#header-home-link` "Home" on `/talk`), update the identity and Talk heading tests and the `data-phx-theme` count in `talk_screen_page_test.exs`; verify they fail
- [x] 2.2 `Layouts.app/1`: `#site-header` with the Fraunces wordmark, the `link` attr and fixed height and padding in `app.css` (tokens only); verify the 2.1 tests pass and the colour gate is green

## 3. Theme toggle

- [x] 3.1 Tests first: one `#theme-toggle` button, both labelled spans, no `[data-phx-theme]`, no system control; verify they fail
- [ ] 3.2 Replace `theme_toggle/1` with the icon button and the label CSS (design decisions 2 and 3); edit the head script for the click handler, keep the `phx:theme` key, `storage` and `prefers-color-scheme` listeners; update the CSP hash in `router.ex`; verify `mix test test/maya_web` passes, CSP test included

## 4. Verify in the browser

- [x] 4.1 Playwright against the running app, 375px, both themes: header height and padding equal on the 3 pages, wordmark font, 44px link and toggle, toggle background and border, accessible name per theme, first visit follows emulated `prefers-color-scheme`, tap persists across `/`, `/talk`, `/factory`, stored choice wins over the phone, no CSP console error, no flash (stored night, first screenshot already dark); verify every row passes and paste the table in the PR
- [x] 4.2 After screenshots at the same 6 settings next to the before ones; reduced motion leaves the toggle with no transition; contrast and colour gate tests green; verify with `mix test`

## 5. Close out

- [ ] 5.1 `docs/design-system.md` header and toggle rule; changelog fragment; `Phone check:` line from Abhishek's phone (both themes, toggle tap on `/` and `/talk`); `mix precommit` and `mix credo` green; verify each command exits 0

## Workflow follow-up

- Archive this change with `openspec-archive-change` in the same PR, then `openspec validate --strict` on the specs.
