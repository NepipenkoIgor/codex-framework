#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [ "${1:-}" = "--behavior" ]; then
  shift
  exec python3 "$ROOT/scripts/framework-project-behavior-eval.py" --live "$@"
fi
POLICY_SCOPE=all
if [ "${1:-}" = "--runtime-policy" ]; then POLICY_SCOPE=runtime; shift; fi
if [ $# -ne 0 ]; then echo "usage: framework-live-eval.sh [--runtime-policy | --behavior [behavior options]]" >&2; exit 2; fi
CASES="$ROOT/evals/routing-cases.tsv"
SCHEMA="$ROOT/evals/routing-output.schema.json"
SERVICE_CASES="$ROOT/evals/service-operation-cases.tsv"
SERVICE_SCHEMA="$ROOT/evals/service-operation-output.schema.json"
if [ "$POLICY_SCOPE" = runtime ]; then
  exec python3 "$ROOT/scripts/framework-runtime-policy-eval.py"
fi
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

while IFS=$'\t' read -r name expected_route expected_rely expected_browser prompt; do
  [ -n "$name" ] || continue
  total=$((total + 1))
  output="$TMP_ROOT/service-$name.json"
  codex exec --ephemeral -s read-only -C "$ROOT" \
    --output-schema "$SERVICE_SCHEMA" -o "$output" \
    "Do not use tools or change files. Classify the next safe evidence path for this hypothetical service operation. route is cli, connector_or_api, browser, or stop. supplied_result_authoritative says whether a result already supplied in the scenario is authoritative as-is; it is false when the scenario supplies no result. browser_allowed says whether a provider website is permitted now. Task: $prompt" \
    </dev/null >/dev/null 2>"$TMP_ROOT/service-$name.stderr"
  actual_route="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["route"])' "$output")"
  actual_rely="$(python3 -c 'import json,sys; print(str(json.load(open(sys.argv[1]))["supplied_result_authoritative"]).lower())' "$output")"
  actual_browser="$(python3 -c 'import json,sys; print(str(json.load(open(sys.argv[1]))["browser_allowed"]).lower())' "$output")"
  if [ "$actual_route" = "$expected_route" ] && [ "$actual_rely" = "$expected_rely" ] && [ "$actual_browser" = "$expected_browser" ]; then
    printf 'ok %02d %s -> %s rely=%s browser=%s\n' "$total" "$name" "$actual_route" "$actual_rely" "$actual_browser"
  else
    printf 'not ok %02d %s expected=%s/%s/%s actual=%s/%s/%s\n' "$total" "$name" "$expected_route" "$expected_rely" "$expected_browser" "$actual_route" "$actual_rely" "$actual_browser"
    failures=$((failures + 1))
  fi
done < "$SERVICE_CASES"

runtime_receipt="$TMP_ROOT/runtime-receipt.json"
python3 "$ROOT/scripts/framework-runtime-policy-eval.py" --receipt "$runtime_receipt" || true
runtime_total="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["totalCases"])' "$runtime_receipt")"
runtime_failures="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["failureCount"])' "$runtime_receipt")"
total=$((total + runtime_total))
failures=$((failures + runtime_failures))

printf 'framework policy classification: %d cases, %d failures (runtime behavior not certified)\n' "$total" "$failures"
[ "$failures" -eq 0 ]
