#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

ROOT="$(project_root)"
FRAMEWORK_ROOT="$(framework_root)"
failures=0

fail_check() {
  printf 'memory contract: %s\n' "$1"
  failures=$((failures + 1))
}

status="$(bash "$FRAMEWORK_ROOT/scripts/memory-state.sh" status)"
memory_dir="$(printf '%s\n' "$status" | sed -n 's/^memory_dir=//p')"
source="$(printf '%s\n' "$status" | sed -n 's/^source=//p')"
canonical="$(printf '%s\n' "$status" | sed -n 's/^canonical=//p')"

expected="$ROOT/.codex-memory"

[ "$canonical" = "$expected" ] || fail_check "canonical path mismatch: $canonical"
[ "$memory_dir" = "$expected" ] || fail_check "memory_dir is not canonical: $memory_dir"
[ "$source" = "canonical" ] || fail_check "source is not canonical: $source"
[ -w "$memory_dir" ] || fail_check "memory_dir is not writable: $memory_dir"

for file in project.md preferences.md decisions.local.md episodes.jsonl; do
  [ -e "$memory_dir/$file" ] || fail_check "missing memory file: $file"
done

for entry in '/.codex/memory/' '/.codex-memory/'; do
  grep -qxF "$entry" "$ROOT/.gitignore" 2>/dev/null \
    || fail_check ".gitignore missing $entry"
done

if ! bash "$FRAMEWORK_ROOT/scripts/memory-state.sh" doctor >/dev/null; then
  fail_check "memory doctor failed"
fi

if [ "$failures" -gt 0 ]; then
  printf 'memory contract check: %d failures\n' "$failures"
  exit 1
fi

printf 'memory contract check passed\n'
