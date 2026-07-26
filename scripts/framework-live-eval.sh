#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CASES="$ROOT/evals/routing-cases.tsv"
SCHEMA="$ROOT/evals/routing-output.schema.json"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

failures=0
total=0
while IFS=$'\t' read -r name expected_profile expected_delegate prompt; do
  [ -n "$name" ] || continue
  total=$((total + 1))
  output="$TMP_ROOT/$name.json"
  codex exec --ephemeral -s read-only -C "$ROOT" \
    --output-schema "$SCHEMA" -o "$output" \
    "Do not use tools or change files. Classify the best native execution owner for this hypothetical task. Set delegate=true only when a separate agent materially improves the work. When delegate=false, profile must be parent; every subagent profile requires delegate=true. Task: $prompt" \
    </dev/null >/dev/null 2>"$TMP_ROOT/$name.stderr"
  actual_profile="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["profile"])' "$output")"
  actual_delegate="$(python3 -c 'import json,sys; print(str(json.load(open(sys.argv[1]))["delegate"]).lower())' "$output")"
  if [ "$actual_profile" = "$expected_profile" ] && [ "$actual_delegate" = "$expected_delegate" ]; then
    printf 'ok %02d %s -> %s delegate=%s\n' "$total" "$name" "$actual_profile" "$actual_delegate"
  else
    printf 'not ok %02d %s expected=%s/%s actual=%s/%s\n' "$total" "$name" "$expected_profile" "$expected_delegate" "$actual_profile" "$actual_delegate"
    failures=$((failures + 1))
  fi
done < "$CASES"

printf 'framework live eval: %d cases, %d failures\n' "$total" "$failures"
[ "$failures" -eq 0 ]
