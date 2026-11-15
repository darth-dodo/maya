# Tasks

## 1. Baseline and tests first

- [ ] 1.1 Baseline: `mix maya.latency` against production (the Supabase query from #40) and 10 phone holds with a name as the first word; record the first-word count and `mic_open_ms` from the Render log in the PR (needs Abhishek's phone and the production log)
- [x] 1.2 LiveView tests: the hold end report logs `warm` and `post_roll_ms`, a non-boolean `warm` is ignored, the button carries `data-post-roll-ms`; verify they fail first (green in CI on #101; the red run was not seen, the local Postgres was hung)

## 2. Build

- [x] 2.1 Pure helpers in `talk_hook.js`: a pre-roll ring (push a block, keep the last N samples, drain), the mic close decision and `holdReport` with `warm` and `post_roll_ms`; verify with a node check
- [x] 2.2 `TalkHook`: open the mic only when closed, keep it during the turn, pre-roll while idle, close after the idle delay (default 4 s) and on `visibilitychange` hidden and `destroyed`, record the post-roll after release with `uploading` shown at once; verify `mix assets.build`
- [x] 2.3 `TalkLive`: accept and log `warm` and `post_roll_ms`, render `data-post-roll-ms`; verify the tests from 1.2 pass

## 3. Verify

- [x] 3.1 All gates (`factory:test`), each exit code checked (tests in CI)
- [ ] 3.2 Phone check on iPhone and Android: 10 holds make 10 Questions, the first word is kept, the last word is kept when released right as the Guest finishes speaking, the orange dot goes off about 5 s after the last Answer; numbers before and after in the PR

## Workflow follow-up

- Archive the change in the same PR (`openspec-archive-change`).
