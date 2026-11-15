# Tasks

## 1. Docs

- [x] 1.1 ADR-008 "Guest sessions", ADR-006 partly superseded, index; PRODUCT.md "Who and where", ARCHITECTURE.md 2 and 4, GLOSSARY.md **Guest**, PHASE_2.md; verify the files

## 2. Data (tests first)

- [x] 2.1 Migration: `guest_id` on `turns` and `progress`, legacy backfill, indexes, progress id sequence; verify the legacy backfill test
- [x] 2.2 `GameData.progress/1` seeds per guest; `import!/1` seeds game data only; release test; verify game data and release tests
- [x] 2.3 `Turn` carries and filters by `guest_id`; verify Conversation tests

## 3. Processes and agent (tests first)

- [x] 3.1 `Conversation.start_or_find/1`, registry key `{:conversation, guest_id}`, transient restart, idle stop; verify isolation, crash and idle tests
- [x] 3.2 `Agent.answer/3` takes `guest_id`; verify the per-guest Next gym test

## 4. Web (tests first)

- [x] 4.1 `MayaWeb.Plugs.GuestId` and the session `max_age`; verify plug tests
- [x] 4.2 TalkLive reads the guest id; Start fresh confirm step and `POST /fresh`; verify TalkLive and controller tests

## 5. Gates

- [x] 5.1 Run `factory:test`; verify every gate is green and the coverage floor is not lowered

## Workflow follow-up

- Archive with `openspec-archive-change guest-sessions` in the same PR.
- Abhishek: on the phone, two browsers get separate Conversations, Start fresh empties the screen, the Roxanne Question still works; paste `mix maya.latency` before and after.
