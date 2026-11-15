#!/usr/bin/env bash
# Tests scripts/spoiler_probe.sh with canned Answers (PROBE_ANSWERS) and DRY_RUN=1: no network, no credit.
# Run: scripts/spoiler_probe_test.sh
set -u

dir="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d "$dir/../tmp_spoiler_probe.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT
fails=0

# answers <file> <answer for every probe> [<index> <answer>]: 20 Answers, one optionally replaced.
answers() {
  jq -n --arg all "$2" --arg i "${3:--1}" --arg one "${4:-}" \
    '[range(20)] | map(if . == ($i | tonumber) then $one else $all end)' >"$1"
}

# check <name> <want substring> <reject substring or ""> env...
check() {
  local name="$1" want="$2" reject="$3" out code
  shift 3
  out="$(env DRY_RUN=1 "$@" bash "$dir/spoiler_probe.sh" 2>&1)"
  code=$?
  if [ "$code" -ne 0 ]; then
    echo "FAIL $name: exit $code"; fails=$((fails + 1))
  elif [[ "$out" != *"$want"* ]]; then
    echo "FAIL $name: missing '$want'"; fails=$((fails + 1))
  elif [ -n "$reject" ] && [[ "$out" == *"$reject"* ]]; then
    echo "FAIL $name: unexpected '$reject'"; fails=$((fails + 1))
  else
    echo "pass $name"
  fi
  printf '%s\n' "$out" | tail -4 | sed 's/^/  | /'
}

answers "$tmp/clean.json" "Further ahead. Focus on earning Roxanne's badge first."
answers "$tmp/own.json" "Further ahead." 7 "Groudon is further ahead. Focus on Roxanne first."
answers "$tmp/leak.json" "Further ahead." 0 "Brawly is in Dewford, past Route 106."
answers "$tmp/route.json" "Further ahead." 3 "Try Route 110 later."
answers "$tmp/wording.json" "Further ahead." 1 "You will defeat Roxanne easily."

check "no leak opens nothing" "ok: no leak in 20 Answers" "would open" SMOKE_TOKEN=t PROBE_ANSWERS="$tmp/clean.json"
check "a name from its own Question is not a leak" "ok: no leak" "would open" \
  SMOKE_TOKEN=t PROBE_ANSWERS="$tmp/own.json"
check "a leak opens one Issue" "Found: Dewford, Route 106" "" SMOKE_TOKEN=t PROBE_ANSWERS="$tmp/leak.json"
check "a route past Rustboro is a leak" "would open Issue: bug: spoiler probe leak on" "" \
  SMOKE_TOKEN=t PROBE_ANSWERS="$tmp/route.json"
check "forbidden wording is a leak" "Found: defeat" "" SMOKE_TOKEN=t PROBE_ANSWERS="$tmp/wording.json"
check "no token skips" "skip: SMOKE_TOKEN is not set" "would open" SMOKE_TOKEN= PROBE_ANSWERS="$tmp/leak.json"

[ "$fails" -eq 0 ] && echo "all passed" || echo "$fails failed"
[ "$fails" -eq 0 ]
