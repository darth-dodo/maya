#!/usr/bin/env bash
# Nightly real-model spoiler probe. Spec: openspec/specs/delivery-pipeline, "Scheduled spoiler probe".
# Asks production the 20 probe Questions through POST /health/ask and checks each Answer against the
# forbidden names (minus names in its own Question) and the forbidden wording. One bug Issue per run
# on a leak. Always exits 0: a scheduled check never blocks anything.
# Env: SITE, REPO, PROBES override the defaults; SMOKE_TOKEN is required (skips without it);
# PROBE_ANSWERS is a JSON array of canned Answers in probe order (no request is made);
# DRY_RUN=1 prints the Issue instead of opening it.
set -u

SITE="${SITE:-https://maya-j56u.onrender.com}"
REPO="${REPO:-darth-dodo/maya}"
PROBES="${PROBES:-$(cd "$(dirname "$0")/.." && pwd)/test/fixtures/spoiler_probes.json}"

if [ -z "${SMOKE_TOKEN:-}" ]; then
  echo "skip: SMOKE_TOKEN is not set"
  exit 0
fi

count="$(jq '.probes | length' "$PROBES" 2>/dev/null)" || { echo "skip: cannot read $PROBES"; exit 0; }
leaks=""

for i in $(seq 0 $((count - 1))); do
  question="$(jq -r ".probes[$i].question" "$PROBES")"
  if [ -n "${PROBE_ANSWERS:-}" ]; then
    answer="$(jq -r ".[$i] // empty" "$PROBE_ANSWERS")"
  else
    body="$(jq -n --arg q "$question" '{question: $q}')"
    answer="$(curl -s --max-time 30 -H "x-smoke-token: $SMOKE_TOKEN" -H 'content-type: application/json' \
      --data "$body" "$SITE/health/ask" | jq -r '.answer // empty' 2>/dev/null)"
  fi

  found=""
  # -w -F: whole words, so "Route 11" never matches "Route 110"; -i: any letter case.
  while IFS= read -r name; do
    if ! grep -qiwF -- "$name" <<<"$question" && grep -qiwF -- "$name" <<<"$answer"; then
      found="$found${found:+, }$name"
    fi
  done < <(jq -r '.forbidden[], .forbidden_wording[]' "$PROBES")

  if [ -n "$found" ]; then
    echo "LEAK $question -> $answer ($found)"
    leaks="$leaks- Question: $question
  Answer: ${answer:-empty}
  Found: $found
"
  else
    echo "ok $question"
  fi
done

if [ -z "$leaks" ]; then
  echo "ok: no leak in $count Answers"
  exit 0
fi

title="bug: spoiler probe leak on $(date -u +%Y-%m-%d)"
run="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY:-$REPO}/actions/runs/${GITHUB_RUN_ID:-local}"
body="The nightly spoiler probe found a Spoiler or forbidden wording in a real Answer.

$leaks
Run: $run
Probe set: test/fixtures/spoiler_probes.json"

if [ "${DRY_RUN:-}" = "1" ]; then
  printf 'would open Issue: %s\n%s\n' "$title" "$body"
  exit 0
fi

open="$(gh issue list --repo "$REPO" --state open --search "\"$title\" in:title" --json number --jq length 2>/dev/null || echo unknown)"
if [ "$open" = "unknown" ]; then
  echo "could not check for an open Issue, skipping to avoid a duplicate"
elif [ "${open:-0}" -gt 0 ]; then
  echo "Issue already open for this run's date, not opening another"
else
  gh issue create --repo "$REPO" --label bug --title "$title" --body "$body" || echo "could not open the Issue"
fi
exit 0
