# Tasks

Start from main after `tide-header` merges (the shared header and `#site-header` are needed by the size scenario). Build with Superpowers TDD.

## 1. Baseline

- [ ] 1.1 Before screenshots of `/` and `/talk` (3 stored turns, 6 Team members) at 375px in light and dark (Playwright, `data-theme` set per shot), saved outside the repo; 5 holds on the phone with per-stage p50 for `mic_release_ms`, `stt_ms`, `agent_ms`, `tts_first_byte_ms`, `playback_start_ms`; verify 4 images and the numbers exist (4 before images done; the phone p50s are pending Abhishek's phone)

## 2. Talk screen without containers

- [x] 2.1 Tests first in `talk_screen_page_test.exs` for the added and modified scenarios that a rendered page can check (header parts, ball in `#trainer-card`, Safari fallback line in `app.css`, no scrim literal); update the old scrim and gold hairline assertions; verify the new ones fail and the state, mic and voice assertions are unchanged
- [x] 2.2 CSS: drop the scene panel and card box, the shared band fade (design decisions 1 and 2), the ball left of the eyebrow, the `content: "·";` fallback; verify 2.1 passes, the colour gate is green and `git diff --stat assets/js/talk_hook.js` is empty
- [x] 2.3 Turns like the real turn (design decision 3); verify the chat tests pass

## 3. Homepage

- [x] 3.1 Tests first for the identity and hero scenarios (new `h1`, old text gone), then the headline swap, italic 600 size, the Fraunces italic `@font-face` and woff2 (design decision 4) and the bottom fade (F1); verify `page_controller_test.exs` passes and `/fonts/fraunces-latin-wght-italic.woff2` answers 200 `font/woff2`
- [x] 3.2 Review fixes: delete the dead demo and `.home-catchphrase` CSS, keep `.home-hero .pokeball`, scope `.promise-band` under `.home-tide`; verify `grep -n "demo-\|\.home-catchphrase" assets/css/app.css` is empty and `/factory` renders its ball at the same size as before

## 4. Verify in the browser

- [x] 4.1 Playwright against the running app at 375px, both themes: Talk screen border, radius and background image, card border, radius and shadow, no sideways scroll, header, band and button heights equal across moments, band art per theme and fade stop vs eyebrow and ball, ball 56 to 64px and left of the eyebrow, band shorter than the hero, Question size equal to `#real-turn-question`, latest Answer 22 to 26px ink, hero 500 to 620px, headline 48 to 56px italic 600 Fraunces, hero fade transparent for 96px and solid by 144px and above the eyebrow, reduced motion leaves no animation; verify every row passes and paste the table in the PR
- [ ] 4.2 After screenshots at the same 4 settings next to the before ones; 5 phone holds after, no stage more than 100 ms slower than 1.1; contrast, colour gate and font tests green; verify with `mix test` (after images, contrast, colour gate and font tests done; the phone holds are pending Abhishek's phone)

## 5. Close out

- [ ] 5.1 `docs/design-system.md`: replace the Talk scrim rule with the band fade rule, add the italic font row; changelog fragment; `Phone check:` line from Abhishek's phone (both themes, a full hold on `/talk`); `mix precommit` and `mix credo` green; verify each command exits 0 (docs, fragment and gates done; the `Phone check:` line is pending Abhishek's phone)

## Workflow follow-up

- Archive this change with `openspec-archive-change` in the same PR, after `tide-header` is archived, then `openspec validate --strict` on the specs.
