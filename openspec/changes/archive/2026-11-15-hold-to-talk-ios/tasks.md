# Tasks

## 1. Tests first

- [x] 1.1 LiveView tests: the hold end report is logged at info, a bad report is ignored, the button keeps its static `data-state` while the root follows the moment (DB tests run in CI only: local Docker was hung)

## 2. Build

- [x] 2.1 `TalkLive`: `hold_ended` event, logged at info; verify the tests compile
- [x] 2.2 `TalkHook`: `holdReport`, idempotent release by event, `lostpointercapture` noted, non-passive `touchstart`, `updated()` restores the state; verify `holdReport` with node and `mix assets.build`
- [x] 2.4 `TalkHook` (#79): a fresh mic per press, `recording` only once live, `closeMic` on release and cancel, mic open time in the report; verify `closeMic` and `holdReport` with node
- [x] 2.3 `app.css`: no shrink while `recording`, no pointer events on the button's children; verify `mix assets.build`

## 3. Verify

- [x] 3.1 All gates (`factory:test`), each exit code checked
- [x] 3.2 Phone check written in the PR for Abhishek on iPhone Chrome and Safari: a 5 second hold records 5 seconds, 10 holds make 10 Questions, Render log shows the hold end reasons
