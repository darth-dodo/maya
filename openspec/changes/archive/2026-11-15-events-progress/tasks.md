# Tasks

Local Docker was hung during the build, so the DB tests (marked CI) ran only in CI on the PR.

## 1. Data (tests first)

- [x] 1.1 Migration: `events` (guest_id, kind, details jsonb, previous jsonb, inserted_at), indexed by guest_id; verify `mix test` migrates it (CI)
- [x] 1.2 `locations.json` through Dewford Town (badges required 1); verify the game data test (Route 104 and Dewford inside at 1 badge, Mauville not) (CI) and the vocabulary test (local)

## 2. Events (tests first)

- [x] 2.1 Badge names in `Maya.Horizon`; pure `Maya.Events.change/4` for the six kinds with validation and confirm or refusal lines; verify `test/maya/events_test.exs` (local, 18 tests)
- [x] 2.2 `Maya.Events.log/3`: transaction, row lock, Event row with the previous snapshot, undo; verify `test/maya/events_log_test.exs` (two Guests, undo, refusal writes nothing) (CI)

## 3. Agent (tests first)

- [x] 3.1 `log_event` definition and `Tools.call/3`; Progress threaded through a round; verify the tools and agent tests ("I just earned Roxanne's badge" moves the Next gym to Brawly, undo restores, a later badge is refused) (CI)
- [x] 3.2 System prompt rule for `log_event` and undo; verify the prompt tests, inclusive language included (local)

## 4. Docs and gates

- [x] 4.1 ARCHITECTURE.md 3 and 4 (log_event kinds and validation, locations through Dewford); verify the files
- [x] 4.2 Local gates: compile with warnings as errors, format, credo, sobelow, deps.audit, `openspec validate --all --strict`; archive this change
