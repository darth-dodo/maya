# Tasks

## 1. Baseline and tests first

- [ ] 1.1 Baseline `mix maya.latency` p50 and p95 per stage from production (the #40 Supabase query); paste in the PR
- [x] 1.2 Conversation tests: countdown then agent, edit and send, cancel stores nothing, a new Question discards the pending one, typed turn stored with blank STT stages, `confirm_ms` stored; verify they fail first (run in CI: no local Postgres in this worktree)
- [x] 1.3 LiveView tests by DOM id: `#pending-question` and `#pending-countdown`, `#edit-form` send and cancel, empty and 301 character text not sent, `#type-button` flow; verify they fail first (run in CI: no local Postgres in this worktree)

## 2. Build

- [x] 2.1 Migration `turns.confirm_ms` and `turns.typed`; `Turn` and `Latency` stages include `confirm_ms`; verify `mix ecto.migrate` and the latency test
- [x] 2.2 Conversation: `:confirm` and `:editing` stages, `edit/1`, `send_pending/2`, `cancel_pending/1`, `typed/2`, `:confirm_ms` config; verify 1.2 passes
- [x] 2.3 TalkLive and markup: pending bubble with countdown, editor, keyboard button and type form, 44 px targets, reduced motion CSS; inclusive copy; verify 1.3 passes and `mix assets.build`
- [x] 2.4 TalkHook: `question_cancelled` to `idle`, `typed` to `waiting` with the release mark at Send; verify `mix assets.build` and a node check

## 3. Verify

- [ ] 3.1 All gates (`factory:test`), each exit code checked
- [ ] 3.2 Phone check: 5 untouched holds, 2 edits, 1 cancel, 2 typed Questions; per-stage p50 and p95 before and after (with `confirm_ms`) in the PR; screenshots of the countdown and editor shown before review
- [x] 3.3 Docs: ARCHITECTURE.md voice loop sequence and the turns table gain the countdown and typed Questions; GLOSSARY.md if a new term (pending Question) is used

## Workflow follow-up

- Archive the change in the same PR (`openspec-archive-change`).
