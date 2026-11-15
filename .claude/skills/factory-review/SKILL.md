---
name: factory:review
description: Use when reviewing a Maya PR or branch before Abhishek merges, combining Matt's code-review with the factory's definition of done and conventions, and reporting blocking versus non-blocking findings.
---

# factory:review

Review station (FACTORY.md line 5). Argument: a PR number or branch. Read the code and the Issue; never review from the diff summary alone.

## 1. Code review

Invoke `mattpocock-skills:code-review` against `origin/main` (merge base). Its two axes: Standards (this repo's conventions) and Spec (the Issue and its OpenSpec change).

## 2. Factory checklist

| Check | Blocking if missing |
|---|---|
| `Closes #N`, Issue "done when" each shown with evidence | Yes |
| `factory:test` green, CI `ci-success` green | Yes |
| OpenSpec change archived in this PR, `openspec/specs/` matches the code | Yes, if the Issue has a change |
| No secrets, `.env` untouched, new env vars in `render.yaml`, `runtime.exs` and FACTORY.md secrets table | Yes |
| Frozen stack respected, or an ADR added | Yes |
| Voice loop touched: latency numbers, or the stated reason they are missing | Yes |
| Changelog fragment in `changelog.d/` (no edit to `CHANGELOG.md`), Conventional Commit title | No |
| No em or en dashes, name written as "Maya" | No |

## 3. Report

Two lists, blocking then non-blocking, each finding with an id, `file:line` and the smallest fix. Ids run F1, F2, ... across both lists and never repeat in one comment. Under the lists, the same findings as one table, so `factory:retro` can parse them:

```markdown
### Findings
| id | severity | file:line | finding |
|---|---|---|---|
| F1 | Blocking | lib/maya/agent.ex:42 | Timeout bounds each request, not the stage |
| F2 | Non-blocking | test/maya/agent_test.exs:10 | Raw HTML match, select by DOM id |
```

Severity is exactly `Blocking` or `Non-blocking`. A file-wide finding uses `file:1`; a finding with no file uses `-`. No findings: the table with no rows. Checklist passes and "not verified" notes are not findings. Post the same as one PR comment (`gh pr comment <n> --body-file <file>`). Never approve or merge; Abhishek merges.
