# Factory lessons

Rules the factory learned the hard way, grouped by station. Each one cites the PR or Issue it came from.
`factory:build` reads this file at step 4. Change it only through a `factory:improve` PR. Keep it under 40 rules.

## Plan
- Always create the Issue (`factory:plan` step 6) and link it to the spec PR, because a change without an Issue is invisible to `next-task`: the dry run's spec PR had no Issue until one was added by hand (#12, #13, #15).

## Build
- Use the Supabase session pooler URI (`aws-0-eu-west-1.pooler.supabase.com:5432`) as `DATABASE_URL`, never the project API URL (`Ecto.InvalidURLError`), the direct host (IPv6 only, `nxdomain`) or port 6543 (transaction pooler, breaks prepared statements) (#4, #5, #7).
- Generate `SECRET_KEY_BASE` with `mix phx.gen.secret` and check it is 64+ bytes, because a short key passes `/health` but 500s every session page, so a broken deploy goes live (#8).
- Read env vars only in `config/runtime.exs` and list them in the FACTORY.md secrets table, never in controllers, because reviewers block direct `System.get_env` in `lib/` (#22).
- Deny overlapping plugin skills with `Skill(skill:<name>)` rules in `.claude/settings.json`, because `skillOverrides` does nothing for plugin skills (#9).
- In a worktree, run the DB with `docker compose -p maya up -d --wait db`, because the `-p maya` reuses the main checkout's container instead of starting a second one on the same port (#21, #22).
- Run `mix format` before the first `factory:test`, and select by DOM id in tests (`#tagline`), not raw HTML matches, per AGENTS.md, because the dry run's only red gate was format and its main review finding was raw HTML matching (#16).
- When a branch conflicts with `main`, `git merge origin/main` and keep both sides, because force push is denied and rebasing a pushed branch needs it (#21). Merge main into every open builder branch right after a convention PR merges, because #25 conflicted on CLAUDE.md after #23 landed (#25).

## Verify
- Run every gate on its own and judge it by its exit code, never through `| tail` or `| grep`, because a pipe reports the last command's status and hides a red gate (#15).
- Tick a `tasks.md` box only after its own verification ran, because a ticked task with missing work became a blocking review finding (#22).
- Prove a new gate can fail (one red run, local or in CI, then green) before trusting it, because a gate that never fails proves nothing (#22).
- Give every `curl` in a workflow `--max-time`, because a hung request runs into `timeout-minutes`, ends as cancelled and skips `if: failure()` steps (#22).

## Review
- Check each Issue "done when" against the skill and doc files too, not only the code, because review found a skill that never named the new checks (#22).

## Ship
- Add a changelog fragment `changelog.d/<branch-with-dashes>.md`, never a line in `CHANGELOG.md`, because a file every PR appends to made nearly every parallel PR conflict (#23).
- Run any check that waits for the deploy on a schedule, never as a check on the commit Render is waiting for, because a push-triggered smoke check deadlocked `checksPass` and blocked every deploy (#22, #28).
- Make every check on the head commit finish fast and exit 0 unless the code is broken, because Render's `checksPass` waits on pending checks and refuses failed ones (#28).
