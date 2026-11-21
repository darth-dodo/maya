# Tasks

## 1. Baseline and tests first

- [ ] 1.1 Baseline `mix maya.latency` p50 and p95 per stage from production (the #40 Supabase query); paste in the PR
- [ ] 1.2 Conversation tests: the agent is asked at once beside the countdown, an edit discards the in-flight Answer and asks the edited text, cancel stores nothing, a new hold discards the pending one, the countdown end closes the edit window, typed turn stored with blank STT stages, `confirm_ms` stored; verify they fail first
- [ ] 1.3 LiveView tests by DOM id: `#pending-question`, `#edit-input` and `#pending-countdown`, focus on `#edit-input` then `#edit-form` send and cancel, readonly after the countdown, empty and 301 character text not sent, `#type-button` focusing `#type-input` in the tap; verify they fail first

## 2. Build

- [ ] 2.1 Migration `turns.confirm_ms` and `turns.typed`; `Turn` and `Latency` stages include `confirm_ms`; verify `mix ecto.migrate` and the latency test
- [ ] 2.2 Conversation: the agent starts at once, a `pending` flag and `{:confirm_end, ref}` timer, an `:editing` stage, `edit_pending/1`, `send_pending/2`, `cancel_pending/1`, `typed/2`, `:confirm_ms` config; verify 1.2 passes
- [ ] 2.3 TalkLive and markup: pending bubble with countdown, editor, keyboard button and type form, 44 px targets, reduced motion CSS; inclusive copy; verify 1.3 passes and `mix assets.build`
- [x] 2.4 TalkHook: `question_editing` and `question_cancelled` to `idle`, `asked` to `waiting` (a typed Question's release mark at Send, an edited one keeps the hold's), the AudioContext woken in the Send gesture; verify `mix assets.build` and `node --test`

## 3. Verify

- [ ] 3.1 All gates (`factory:test`), each exit code checked
- [ ] 3.2 Phone check: 5 untouched holds, 2 edits, 1 cancel, 2 typed Questions; per-stage p50 and p95 before and after (with `confirm_ms`) in the PR; screenshots of the countdown and editor shown before review
- [x] 3.3 Docs: ARCHITECTURE.md voice loop sequence and the turns table gain the countdown and typed Questions; GLOSSARY.md if a new term (pending Question) is used

## Workflow follow-up

- Archive the change in the same PR (`openspec-archive-change`).
