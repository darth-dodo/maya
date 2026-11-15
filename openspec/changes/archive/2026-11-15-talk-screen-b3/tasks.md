# Tasks

## 1. Tests first

- [x] 1.1 Talk screen tests: ids, trainer card from seed and earned Progress, all 8 badges, moments via `talk_state`, unknown moment ignored, status text and wave, last 3 turns, nothing heard line, button parts; green in CI run 43693600965 (local Docker was hung, so the red run was not observed locally)
- [x] 1.2 Landing page tests: one hidden `h1`, no hero, ball in the card, badge case from Progress and kept after a turn, no spoilers past the Next gym; green in CI run 43693600965 (local Docker was hung, so the red run was not observed locally)

## 2. Build

- [x] 2.1 `TalkLive`: trainer card assigns, `talk_state` event, new markup; verify the tests pass
- [x] 2.2 `TalkHook`: push `talk_state` on change and on reconnect, stop writing the button text; verify `mix assets.build`
- [x] 2.3 `app.css`: scene, card, shrink, ring, wave, chat, pinned button, type colours, reduced motion; viewport meta; verify `mix assets.build`

## 3. Verify

- [x] 3.1 All gates (`factory:test`); verify each exit code (DB tests in CI run 43693600965)
- [x] 3.2 Screenshots at 375 px and 1280 px, contrast and no horizontal scroll, or say why they need the deployed app
