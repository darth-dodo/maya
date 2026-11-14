# Tasks

## 1. Spoiler horizon

- [x] 1.1 Write `test/maya/horizon_test.exs` for the Next gym, badges earned and allowed locations (0 and 1 badges, unlisted fails closed); verify it fails, then add `Maya.Horizon` and verify it passes

## 2. Parsers

- [x] 2.1 Write parser tests on small fixtures (trainer parties, encounters, PokeAPI species, types, evolution chain); verify they fail, then add the pure parsers and verify they pass

## 3. Fetch

- [x] 3.1 Add `mix maya.fetch_data` (pinned commit, PokeAPI), run it once, commit `priv/data/`; verify the file sizes and that Roxanne and Ralts are in the files

## 4. Import

- [x] 4.1 Write import tests (Roxanne's team, Ralts' Route 102 rate, nine locations, Progress seed and keep, idempotency); verify they fail, then add the migration, `priv/progress.json`, `Maya.GameData`, `mix maya.import` and `Maya.Release.import_data/0` and verify they pass

## 5. Gates

- [x] 5.1 Run `factory:test`; verify every gate is green and the coverage floor is not lowered
