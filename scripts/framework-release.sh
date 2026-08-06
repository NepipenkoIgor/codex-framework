#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QUALITY_DIR=""

if [ "${1:-}" = "--quality-dir" ]; then
  [ $# -eq 2 ] || { printf 'usage: framework-release.sh [--quality-dir PATH]\n' >&2; exit 1; }
  QUALITY_DIR="$2"
elif [ $# -ne 0 ]; then
  printf 'usage: framework-release.sh [--quality-dir PATH]\n' >&2
  exit 1
fi

OWN_QUALITY_DIR=0
if [ -z "$QUALITY_DIR" ]; then
  QUALITY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codex-framework-release-quality.XXXXXX")"
  OWN_QUALITY_DIR=1
fi
cleanup() {
  [ "$OWN_QUALITY_DIR" -eq 0 ] || rm -rf -- "$QUALITY_DIR"
}
trap cleanup EXIT
GATE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codex-framework-release-gates.XXXXXX")"
cleanup_gates() { rm -rf -- "$GATE_DIR"; }
trap 'cleanup_gates; cleanup' EXIT

run_gate() {
  local name="$1"
  shift
  "$@" | tee "$GATE_DIR/$name.log"
  {
    printf 'command:'
    printf ' %q' "$@"
    printf '\noutput-sha256: %s\n' "$(shasum -a 256 "$GATE_DIR/$name.log" | awk '{print $1}')"
  } > "$GATE_DIR/$name.passed"
}

run_gate deterministic-health bash "$ROOT/scripts/framework-health.sh"
run_gate effective-install-doctor bash "$ROOT/scripts/framework-doctor.sh" --skip-evidence
run_gate native-skill-loader-canary bash "$ROOT/scripts/framework-skill-loader-live-eval.sh"
run_gate live-version-resolution bash "$ROOT/scripts/framework-version-drift-check.sh" --live

if [ -f "$QUALITY_DIR/routing-framework-management.json" ] && [ -f "$QUALITY_DIR/quality-framework-management.json" ]; then
  python3 "$ROOT/scripts/framework-skill-quality.py" certify --skill framework-management --artifact-dir "$QUALITY_DIR"
else
  bash "$ROOT/scripts/framework-skill-routing-live-eval.sh" --skill framework-management --artifact-dir "$QUALITY_DIR"
  python3 "$ROOT/scripts/framework-skill-quality.py" semantic-live \
    --skill framework-management \
    --artifact-dir "$QUALITY_DIR" \
    --routing-artifact "$QUALITY_DIR/routing-framework-management.json"
  python3 "$ROOT/scripts/framework-skill-quality.py" certify --skill framework-management --artifact-dir "$QUALITY_DIR"
fi

python3 "$ROOT/scripts/framework-release-evidence.py" write --artifact-dir "$QUALITY_DIR" --gate-dir "$GATE_DIR" >/dev/null
python3 "$ROOT/scripts/framework-release-evidence.py" check

printf 'framework release gate passed\n'
