# Factory lessons

Rules the factory learned the hard way, grouped by station. Each one cites the PR or Issue it came from.
`factory:build` reads this file at step 4. Change it only through a `factory:improve` PR. Keep it under 40 rules.

## Plan
- Always create the Issue (`factory:plan` step 6) and link it to the spec PR, because a change without an Issue is invisible to `next-task`: the dry run's spec PR had no Issue until one was added by hand (#12, #13, #15).
- When a design session or grill changes a rule, update every doc that states it in the same PR, because #27 left the old voice fallback in three other files until review (#27).
- Give every PR an Issue with an estimate, even small follow-ups, because PRs without one have blank retro cells and are invisible to `next-task` (#30, #34, #35).
- Score an experiment only with a metric its change can move, because E3's hourly text Question was scored on escaped defects that were all phone-only bugs it could never catch (#63, #74).

## Build
- Use the Supabase session pooler URI (`aws-0-eu-west-1.pooler.supabase.com:5432`) as `DATABASE_URL`, never the project API URL (`Ecto.InvalidURLError`), the direct host (IPv6 only, `nxdomain`) or port 6543 (transaction pooler, breaks prepared statements) (#4, #5, #7).
- Generate `SECRET_KEY_BASE` with `mix phx.gen.secret` and check it is 64+ bytes, because a short key passes `/health` but 500s every session page, so a broken deploy goes live (#8).
- Read env vars only in `config/runtime.exs` and list them in the FACTORY.md secrets table, never in controllers, because reviewers block direct `System.get_env` in `lib/` (#22).
- Deny overlapping plugin skills with `Skill(skill:<name>)` rules in `.claude/settings.json`, because `skillOverrides` does nothing for plugin skills (#9).
- In a worktree, run the DB with `docker compose -p maya up -d --wait db`, because the `-p maya` reuses the main checkout's container instead of starting a second one on the same port (#21, #22).
- Run `mix format` before the first `factory:test`, and select by DOM id in tests (`#tagline`), not raw HTML matches, per AGENTS.md, because the dry run's only red gate was format and its main review finding was raw HTML matching (#16).
- When a branch conflicts with `main`, `git merge origin/main` and keep both sides, because force push is denied and rebasing a pushed branch needs it (#21). Merge main into every open builder branch right after a convention PR merges, because #25 conflicted on CLAUDE.md after #23 landed (#25).
- Run a format or API spike with a real key before writing the decode path, because #48 assumed int16 PCM and needed a float32 fix after it ran against Voxtral (#48).
- Run one plain command per tool call and keep temp files inside the worktree, because compound commands and paths outside it were the builders' denied calls (#47, #48).
- Send provider defaults explicitly when the product needs one value (STT language `en`), because Voxtral guessed Hindi per clip on English Questions until #59 sent the language (#59).
- Never change layout under an active touch (no resize, reflow or LiveView patch of the pressed element while a finger is down), because #74 shrank the trainer card under the finger and broke hold to talk on iPhone (#74, #76).
- Make tool-driven writes idempotent (one Event per tool call), because #86 applied a repeated catch twice and filled the Team with duplicates (#86, #116).
- Let Maya state only tool results she received, never the result of a tool she did not call, because Answers claimed refusals from tools that never ran (#55, #118).
- Never push to a branch whose PR already merged; start a new branch from `origin/main`, because commits pushed to #54's merged branch were lost until #71 carried them (#71).
- Log the reason of every failed stage (an atom, status or exception message, never transcripts, Answers or keys), because #55's Conversation logged nothing and its root cause needed a Render trace (#60).
- Answer an infrastructure flake with the tool's documented fallback setting, not a retry, because #42's Hex outage maps to setup-beam's `hexpm-mirrors` and #52 fixed it in one line (#52).

## Verify
- Run every gate on its own and judge it by its exit code, never through `| tail` or `| grep`, because a pipe reports the last command's status and hides a red gate (#15).
- Tick a `tasks.md` box only after its own verification ran, because a ticked task with missing work became a blocking review finding (#22).
- Prove a new gate can fail (one red run, local or in CI, then green) before trusting it, because a gate that never fails proves nothing (#22).
- Make optional external reporters non-blocking and prove their failure path in CI before relying on them, because #53's Codecov upload failed without a token and CI stayed green as designed (#53).
- Check every press path or Talk layout change on a real phone before merge, with the largest real data (a full Team at 375 px), because #81's fresh mic per press cut the first words (#94) and #84's sticky card covered a third of the screen (#117), and only the phone showed either; `factory:review` blocks on a `Phone check:` line (#81, #84, E4).
- Give every `curl` in a workflow `--max-time`, because a hung request runs into `timeout-minutes`, ends as cancelled and skips `if: failure()` steps (#22).

## Review
- Check each Issue "done when" against the skill and doc files too, not only the code, because review found a skill that never named the new checks (#22).
- Show visual and copy options (screenshots, a page, 2 or 3 taglines) before review, because the welcome page changed twice after review (#24) and #54 took three post-review commits to settle its lines (#24, #54).
- Post the `factory:review` comment, and wait for it, before the PR is merged, because #47 merged with no review comment and #100 merged before its 2 blockers, which needed a follow-up PR (#47, #100, #102).

## Ship
- Add a changelog fragment `changelog.d/<branch-with-dashes>.md`, never a line in `CHANGELOG.md`, because a file every PR appends to made nearly every parallel PR conflict (#23).
- Run CI on the merge result of parallel PRs before the second one merges, and grep callers on the latest `origin/main` when changing a public function's arity, because #63 and #65 were each green and together broke main (#63, #65, #72).
- Run any check that waits for the deploy on a schedule, never as a check on the commit Render is waiting for, because a push-triggered smoke check deadlocked `checksPass` and blocked every deploy (#22, #28).
- Make every check on the head commit finish fast and exit 0 unless the code is broken, because Render's `checksPass` waits on pending checks and refuses failed ones (#28).
- Make the deploy step leave production able to run (migrate, then seed the data the app reads), never a manual import, because #55 shipped to an empty Progress table and every Answer failed until #60 seeded on deploy (#55, #60).
- Check after each deploy that one real Question works against production data, not only that CI passed on fixtures, because #55 was green in CI and failed every Question in production; the hourly smoke Question does this (#55, E3).
- Cut a release only after its queued PRs merge, because #33's changelog fragment missed v0.1.0 by 38 seconds (#33, #34).

