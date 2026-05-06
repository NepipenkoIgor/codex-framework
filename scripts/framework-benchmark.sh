#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/scripts/lib.sh"

CASES_FILE="${1:-$ROOT/templates/framework-benchmark.tsv}"
[ -f "$CASES_FILE" ] || fail "missing benchmark cases: $CASES_FILE"

total=0
failures=0

while IFS=$'\t' read -r task expected; do
  [ -n "${task:-}" ] || continue
  case "$task" in \#*) continue ;; esac
  total=$((total + 1))
  actual="$(bash "$ROOT/scripts/codex-fw.sh" route "$task")"
  if printf '%s\n' "$actual" | grep -Eq "$expected"; then
    printf 'ok %02d benchmark: %s\n' "$total" "$task"
  else
    printf 'not ok %02d benchmark: %s\n' "$total" "$task"
    printf '  expected: %s\n' "$expected"
    printf '  actual:   %s\n' "$actual"
    failures=$((failures + 1))
  fi
done < "$CASES_FILE"

printf 'framework benchmark: %d cases, %d failures\n' "$total" "$failures"

if [ "$failures" -ne 0 ]; then
  exit 1
fi
