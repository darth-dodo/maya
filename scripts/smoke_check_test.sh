#!/usr/bin/env bash
# Tests scripts/smoke_check.sh against the live site in DRY_RUN mode (needs network and gh auth).
# Run: scripts/smoke_check_test.sh
set -u

dir="$(cd "$(dirname "$0")" && pwd)"
site="${SITE:-https://maya-j56u.onrender.com}"
fails=0

iso() { date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ; }
now="$(date -u +%s)"

# check <name> <want substring> <reject substring or ""> env...
check() {
  local name="$1" want="$2" reject="$3" out code
  shift 3
  out="$(env DRY_RUN=1 SITE="$site" "$@" bash "$dir/smoke_check.sh" 2>&1)"
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
  printf '%s\n' "$out" | sed 's/^/  | /'
}

live="$(curl -sS --max-time 10 "$site/health/version" | tr -d '[:space:]')"

check "live head is ok" "ok:" "would open" HEAD_SHA="$live" HEAD_TIME="$(iso "$now")"
check "old head not live opens an Issue" "not live after 20 minutes" "" \
  HEAD_SHA=deadbeef HEAD_TIME="$(iso $((now - 3600)))"
check "new head not live is in progress" "deploy in progress" "would open" \
  HEAD_SHA=deadbeef HEAD_TIME="$(iso "$now")"

[ "$fails" -eq 0 ] && echo "all passed" || echo "$fails failed"
[ "$fails" -eq 0 ]
