# Tasks

Start from main after #130 (merged). Build with Superpowers TDD. Do not edit `assets/js/talk_hook.js`.

## 1. Baseline

- [ ] 1.1 Before screenshots of `/talk` in light and dark at 375px, empty and with 3 turns (Playwright, `data-theme` set per shot), and per-stage p50 from 5 phone holds; verify 4 images and the numbers are saved for the PR

## 2. Layout

- [ ] 2.1 Failing tests first: `#card-eyebrow` holds `#location` and `#badge-count` (LiveView test), and Playwright computed style checks for header height per moment, art per theme, unboxed turns, hairlines, Answer size, pill size and chip wrap; verify they fail
- [ ] 2.2 Slim header: `#card-eyebrow`, Fraunces gym line, wrapping Team chips, faint art with the 85% scrim per theme, gold hairline at night on the bottom border, shrink rules deleted; verify the header scenarios pass
- [ ] 2.3 Unboxed conversation with hairlines, muted older turns, 24px latest Answer; 72px full-width pill; verify the chat and button scenarios pass and every existing `talk_live_test.exs` and `talk_screen_page_test.exs` test passes with no assertion edits

## 3. Close out

- [ ] 3.1 After screenshots at the same 4 settings next to the before ones; reduced motion leaves the ring, wave and facts still; 44px targets; colour gate, contrast and font tests green; verify with `mix test test/maya_web`
- [ ] 3.2 Phone check on Abhishek's phone: 5 holds, one cut-in while speaking, Start fresh, in both themes, with per-stage p50 after; `docs/design-system.md` updated if a rule changed; changelog fragment; `mix precommit` and `mix credo` green; verify each command exits 0

## Workflow follow-up

- Archive this change with `openspec-archive-change` in the same PR, then `openspec validate --strict` on the specs.
