---
name: factory:release
description: Use right after factory:improve closes a factory:retro batch, or when Abhishek asks for a Maya release, a version, a tag, release notes, or to split unreleased changes into several releases.
---

# factory:release

Flywheel step 3 (FACTORY.md "Flywheel"), after `factory:improve`, before `factory:recap`. A thin station: `release-manager` owns the mechanics (preconditions, SemVer, folding fragments, CHANGELOG.md, tag, notes, deploy check, spoiler probe). This skill decides whether a release is due, gets Abhishek's names, and hands off. Never merge.

## Before every GitHub write

Run `TZ=Europe/Berlin date`. Monday to Friday, 08:00 to 17:59: do not push, open a PR, tag, create a release or comment. Keep the work local and stop. Every message to Abhishek then says only what is ready locally and the next command; it never names the time, the day or a window.

## 1. Is a release due?

Last tag: `git tag --sort=-v:refname` (first line; version order, because split tags are created out of order). Due when either holds:

- a `feat:` PR merged since that tag: `git log <tag>..origin/main --format=%s`, a subject starting `feat` (`feat:`, `feat(scope):`, `feat!:`)
- a block milestone closed since that tag's date: `gh api "repos/darth-dodo/maya/milestones?state=closed" --jq '.[] | [.title,.closed_at] | @tsv'`

Neither: report "No release due: no `feat:` PR or closed block since vX.Y.Z" and stop.

## 2. Propose, then wait

Propose to Abhishek and stop until he answers:

```
Release due: <n> PRs since vA.B.C (<k> feat:, <block> closed)
Version: vX.Y.Z (release-manager step 2: <reason>)
Theme: "<suggestion>", or rename it
Covers: #first to #last
```

- Version comes from `release-manager` step 2. Never pick 1.0.0 unless he said the MVP is done.
- The theme is Abhishek's. Offer one short suggestion from what shipped (like "Maya talks" for v0.2.0); use his name if he gives one. Never "proof", never "premium".
- Asked to split ("up to #150 as one release"): propose one version and theme per range, each range's version from its own commits.

## 3. Release PR

Hand off to `release-manager` step 3 with the confirmed version(s). Its preconditions are not optional.

Split: one PR, not one per release. On one branch `chore/release-vLAST`:

- Fold each fragment into the section of the range its PR is in. `CHANGELOG.md` gets one `## [X.Y.Z] - <date>` section per version, newest on top under the empty `## [Unreleased]`, the `[Unreleased]: .../compare/vNEWEST...HEAD` link, and one compare link per version (`[0.3.0]: .../compare/v0.2.0...v0.3.0`, `[0.4.0]: .../compare/v0.3.0...v0.4.0`).
- `mix.exs` gets only the newest version.
- Title `chore(release): vA.B.C and vX.Y.Z`; body has each section.

## 4. After Abhishek merges

Run `release-manager` step 4, with these factory specifics:

- Release title `vX.Y.Z <Theme>`; the notes file starts `# vX.Y.Z <Theme>`, then one sentence, then the changelog section.
- Split: tag the newest version on the release PR's merge commit. Tag each earlier version on the squash merge commit of the last PR in its range on main (`gh pr view <last> --json mergeCommit --jq .mergeCommit.oid`), and start its notes with: "Tagged on the merge of #<last>; `mix.exs` at this commit still shows <previous version>."
- Deploy check and spoiler probe once, for the newest version.

## 5. Report

```
Released: vA.B.C <Theme> <release url>, vX.Y.Z <Theme> <release url>
Tags: vA.B.C at <sha7> (#<last>), vX.Y.Z at <sha7> (#<release pr>)
Deploy: <result>  Spoiler probe: <run url>
```

When stopped early, say what is ready locally and the next command to run.

## Common mistakes

| Mistake | Instead |
|---|---|
| Naming the theme and carrying on | Suggest one, wait for Abhishek |
| Two release PRs for a split | One PR with several CHANGELOG sections |
| Every split tag on the newest merge commit | Earlier tags on the last merge of their range, with the `mix.exs` note |
| Pushing because the PR "is just a release" | Check the Berlin time before each write |
| Re-implementing fragment folding here | `release-manager` step 3 |
