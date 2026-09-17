#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
QUALITY_DIR=""
ACTIVE_PID=""
DELIVERY_DIR=""
PROVIDER_DIR=""

usage() {
  printf 'usage: framework-release.sh [--quality-dir PATH] [--delivery-artifact-dir PATH]\n' >&2
}
while [ $# -gt 0 ]; do
  case "$1" in
    --quality-dir|--delivery-artifact-dir)
      [ $# -ge 2 ] && [ -n "$2" ] || { usage; exit 1; }
      if [ "$1" = --quality-dir ]; then QUALITY_DIR="$2"; else DELIVERY_DIR="$2"; fi
      shift 2
      ;;
    *) usage; exit 1 ;;
  esac
done
# Reject missing/stale supplied evidence before any paid live gate is started.
if [ -n "$DELIVERY_DIR" ]; then
  DELIVERY_DIR="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).expanduser().resolve())' "$DELIVERY_DIR")"
  python3 "$ROOT/scripts/framework-release-evidence.py" validate-delivery --summary "$DELIVERY_DIR/summary.json"
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
cleanup_gates() {
  rm -rf -- "$GATE_DIR"
  [ -z "$PROVIDER_DIR" ] || rm -rf -- "$PROVIDER_DIR"
}
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

# Execute, rather than merely classify, the native provider-routing decision.
PROVIDER_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codex-framework-provider-behavior.XXXXXX")"
run_stage python3 "$ROOT/scripts/framework-project-behavior-eval.py" --live \
  --case provider-cli-routing --artifact-dir "$PROVIDER_DIR" --timeout 300

# Keep raw native delivery traces separately from skill-corpus artifacts.
# Supplied evidence is reused only after source-bound validation; no live rerun.
if [ -z "$DELIVERY_DIR" ]; then
  DELIVERY_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codex-framework-release-delivery.XXXXXX")"
  printf 'Native delivery artifacts: %s\n' "$DELIVERY_DIR"
  run_stage python3 "$ROOT/scripts/framework-delivery-behavior-eval.py" --live \
    --case pending-evidence --case merge-cleanup --case false-positive --case ci-repair \
    --artifact-dir "$DELIVERY_DIR" --source-root "$ROOT" --timeout 600 > "$DELIVERY_DIR/live.log"
fi
run_gate nativeDeliveryBehavior python3 scripts/framework-release-evidence.py validate-delivery \
  --summary "$DELIVERY_DIR/summary.json" --emit-summary

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
