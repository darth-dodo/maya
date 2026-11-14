#!/usr/bin/env bash
# Scheduled post-deploy smoke check. Spec: openspec/specs/delivery-pipeline, "Post-deploy smoke check".
# Compares the live /health/version with the head of main and opens one bug Issue per broken commit.
# Always exits 0: Render's checksPass waits on every check, so this must never fail or block a deploy.
# Env: SITE, REPO, HEAD_SHA and HEAD_TIME (ISO 8601 UTC) override the defaults; DRY_RUN=1 prints instead of creating.
set -u

SITE="${SITE:-https://maya-j56u.onrender.com}"
REPO="${REPO:-darth-dodo/maya}"
LIMIT_SECONDS=1200

to_epoch() { date -u -d "$1" +%s 2>/dev/null || date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$1" +%s 2>/dev/null; }

if [ -z "${HEAD_SHA:-}" ] || [ -z "${HEAD_TIME:-}" ]; then
  head="$(gh api "repos/$REPO/commits/main" --jq '.sha + " " + .commit.committer.date' 2>/dev/null)"
  HEAD_SHA="${HEAD_SHA:-${head%% *}}"
  HEAD_TIME="${HEAD_TIME:-${head#* }}"
fi
if [ -z "$HEAD_SHA" ] || [ -z "$HEAD_TIME" ]; then
  echo "skip: could not read the head of main"
  exit 0
fi

short="${HEAD_SHA:0:7}"
live="$(curl -sS --max-time 10 "$SITE/health/version" 2>/dev/null | tr -d '[:space:]')"
problem=""

if [ "$live" = "$HEAD_SHA" ]; then
  for path in / /health; do
    status="$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' "$SITE$path")"
    echo "$path -> $status"
    if [ "$status" != "200" ]; then problem="$SITE$path answered $status"; break; fi
  done
else
  t="$(to_epoch "$HEAD_TIME")" || { echo "skip: cannot parse HEAD_TIME '$HEAD_TIME'"; exit 0; }
  age=$(( $(date -u +%s) - t ))
  if [ "$age" -gt "$LIMIT_SECONDS" ]; then
    problem="not live after 20 minutes (live: ${live:-none})"
  else
    echo "deploy in progress: live=${live:-none} head=$HEAD_SHA (${age}s old)"
    exit 0
  fi
fi

if [ -z "$problem" ]; then
  echo "ok: $HEAD_SHA is live and healthy"
  exit 0
fi

echo "problem: $problem"
title="bug: deploy of $short failed the smoke check"
run="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-$REPO}/actions/runs/${GITHUB_RUN_ID:-local}"
body="Commit: $HEAD_SHA
Failure: $problem
Run: $run

If the deploy never went live, check the Render events for this commit."

open="$(gh issue list --repo "$REPO" --state open --search "$short in:title" --json number --jq length 2>/dev/null || echo unknown)"
if [ "$open" = "unknown" ]; then
  echo "could not check for an open Issue for $short, skipping to avoid a duplicate"
  exit 0
fi
if [ "${open:-0}" -gt 0 ]; then
  echo "Issue already open for $short, not opening another"
elif [ "${DRY_RUN:-}" = "1" ]; then
  printf 'would open Issue: %s\n%s\n' "$title" "$body"
else
  gh issue create --repo "$REPO" --label bug --title "$title" --body "$body" || echo "could not open the Issue"
fi
exit 0
