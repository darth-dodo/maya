---
name: release-manager
description: Use when cutting a Maya release, bumping the version, tagging, writing GitHub release notes, or moving CHANGELOG.md Unreleased entries into a version
---

# Release manager

A release is a version label on code already merged to main. Render deploys on every merge to main, not on tags, so a release never ships new code by itself.

The factory runs this skill through `factory:release`, which adds the release-due check, the theme (release title `vX.Y.Z <Theme>`) and split releases.

## 1. Preconditions (stop if any fail)

- `git fetch origin` and work from `origin/main`.
- CI on latest main is green: `gh run list --branch main --limit 1 --json conclusion,headSha`.
- There is something to release: lines under `## [Unreleased]` in `CHANGELOG.md` or fragments in `changelog.d/` (other than README.md).

## 2. Pick the version (SemVer, pre-1.0)

- No tags yet: the first release is the current `version` in `mix.exs` (0.1.0), no bump.
- Otherwise read `git log <last tag>..origin/main --format=%s`:
  - any `feat:` or breaking change (`!` or `BREAKING CHANGE`): bump minor (0.1.0 to 0.2.0)
  - only `fix:`, `chore:`, `docs:`, `refactor:`, `test:`: bump patch (0.1.0 to 0.1.1)
- 1.0.0 only when Abhishek says the MVP is done.
- Cross-check: changelog `Added` lines should match `feat:` commits. Fix gaps before releasing.

## 3. Release PR

1. `git worktree add ../maya-release-vX.Y.Z -b chore/release-vX.Y.Z origin/main`
2. `mix.exs`: set `version: "X.Y.Z"`.
3. Fold fragments: for each `changelog.d/*.md` except README.md, find its PR with `git log --diff-filter=A --format=%s -- <file>` (the squash title ends in `(#N)`), add each line to the matching section (`Added`, `Changed`, `Fixed`, `Removed`) under `## [Unreleased]` with ` (#N)` appended, then `git rm` the fragment.
4. `CHANGELOG.md`: rename `## [Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD` (today), add an empty `## [Unreleased]` above it, and keep these links at the bottom:
   - `[Unreleased]: https://github.com/darth-dodo/maya/compare/vX.Y.Z...HEAD`
   - `[X.Y.Z]: https://github.com/darth-dodo/maya/compare/vPREV...vX.Y.Z` (first release: `https://github.com/darth-dodo/maya/releases/tag/vX.Y.Z`)
5. `mix precommit` green.
6. PR title `chore(release): vX.Y.Z`, body = that version's changelog section.
7. Stop. Abhishek merges.

## 4. After the merge

1. Merge commit: `gh pr view <n> --json mergeCommit --jq .mergeCommit.oid`
2. Tag that commit: `git tag -a vX.Y.Z <sha> -m "vX.Y.Z"` then `git push origin vX.Y.Z`
3. Notes: copy the version's changelog section into a scratchpad file, then `gh release create vX.Y.Z --title vX.Y.Z --notes-file <file>`.
4. Verify: Render deployed the merge commit and `curl -fsS <render url>/health` returns 200 (once `/health` exists).
5. Spoiler probe: `gh workflow run spoiler-probe.yml` (20 real Questions; a leak opens a `bug` Issue).
6. Report: version, release URL, deploy check result, spoiler probe run URL.

## Never

- Tag a commit that is not on main, or retag or delete a pushed tag.
- Release with red CI on main.
- Fix a bad release by rewriting it. Fix forward with a patch release.
