#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QUALITY_DIR=""
ACTIVE_PID=""

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
stop_active() {
  if [ -n "$ACTIVE_PID" ] && kill -0 "$ACTIVE_PID" 2>/dev/null; then
    kill -TERM "$ACTIVE_PID" 2>/dev/null || true
    wait "$ACTIVE_PID" 2>/dev/null || true
  fi
  ACTIVE_PID=""
}
on_signal() {
  stop_active
  exit 130
}
GATE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codex-framework-release-gates.XXXXXX")"
cleanup_gates() { rm -rf -- "$GATE_DIR"; }
trap 'cleanup_gates; cleanup' EXIT
trap on_signal INT TERM HUP

run_stage() {
  "$@" &
  ACTIVE_PID=$!
  set +e
  wait "$ACTIVE_PID"
  local result=$?
  set -e
  ACTIVE_PID=""
  return "$result"
}

run_gate() {
  local name="$1"
  shift
  (cd "$ROOT" && "$@") | tee "$GATE_DIR/$name.log"
}

python3 "$ROOT/scripts/framework-release-evidence.py" self-test

run_gate deterministicHealth bash scripts/framework-health.sh
run_gate tokenEfficiency python3 scripts/framework-token-budget-check.py --live
run_gate effectiveInstallDoctor bash scripts/framework-doctor.sh --skip-evidence
run_gate nativeSkillLoaderCanary bash scripts/framework-skill-loader-live-eval.sh
run_gate liveVersionResolution bash scripts/framework-version-drift-check.sh --live
run_gate nativeCapabilityCurrency python3 scripts/framework-native-capability-check.py --live

if [ "$OWN_QUALITY_DIR" -eq 1 ]; then
  run_stage bash "$ROOT/scripts/framework-skill-routing-live-eval.sh" --artifact-dir "$QUALITY_DIR" --jobs 8
  run_stage python3 "$ROOT/scripts/framework-skill-quality.py" full-live \
    --artifact-dir "$QUALITY_DIR" \
    --routing-artifact "$QUALITY_DIR/routing-all.json" \
    --jobs 8
fi
run_gate skillCorpusCertification \
  python3 scripts/framework-skill-quality.py certify --artifact-dir "$QUALITY_DIR"

python3 "$ROOT/scripts/framework-release-evidence.py" write --artifact-dir "$QUALITY_DIR" --gate-dir "$GATE_DIR" >/dev/null
python3 "$ROOT/scripts/framework-release-evidence.py" check

printf 'framework release gate passed\n'
