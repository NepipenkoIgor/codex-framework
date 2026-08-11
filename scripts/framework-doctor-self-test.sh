#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/codex-framework-doctor-eval.XXXXXX")"
FRAMEWORK_CODEX_HOME="$FIXTURE/.codex"
FRAMEWORK_SKILLS_HOME="$FIXTURE/.agents/skills"
trap 'rm -rf -- "$FIXTURE"' EXIT

printf '%s\n' '{"checks":{"terminal.env":{"status":"warning","summary":"height 13 rows - content may scroll off (recommended >=24)","details":{"terminal size":"80x13"}}}}' > "$FIXTURE/native-warning.json"
python3 "$ROOT/scripts/framework-doctor-native.py" "$FIXTURE/native-warning.json" 0 \
  | grep -q 'native advisory: terminal.env: height 13 rows'
printf '%s\n' '{"checks":{"runtime":{"status":"fail","summary":"runtime is unavailable","details":{}}}}' > "$FIXTURE/native-failure.json"
if python3 "$ROOT/scripts/framework-doctor-native.py" "$FIXTURE/native-failure.json" 1 >/dev/null 2>&1; then
  printf 'native doctor classifier did not reject a real failure\n' >&2
  exit 1
fi

CODEX_HOME="$FRAMEWORK_CODEX_HOME" CODEX_SKILLS_HOME="$FRAMEWORK_SKILLS_HOME" \
  bash "$ROOT/scripts/setup.sh" >/dev/null

CODEX_HOME="$FRAMEWORK_CODEX_HOME" CODEX_SKILLS_HOME="$FRAMEWORK_SKILLS_HOME" \
  bash "$ROOT/scripts/framework-doctor.sh" --framework-only --skip-evidence --skip-prompt-input >/dev/null

rm -- "$FRAMEWORK_SKILLS_HOME/framework-management"
if CODEX_HOME="$FRAMEWORK_CODEX_HOME" CODEX_SKILLS_HOME="$FRAMEWORK_SKILLS_HOME" \
  bash "$ROOT/scripts/framework-doctor.sh" --framework-only --skip-evidence --skip-prompt-input >/dev/null 2>&1; then
  printf 'doctor did not detect a missing managed core skill\n' >&2
  exit 1
fi

CODEX_HOME="$FRAMEWORK_CODEX_HOME" CODEX_SKILLS_HOME="$FRAMEWORK_SKILLS_HOME" \
  bash "$ROOT/scripts/setup.sh" >/dev/null
CODEX_HOME="$FRAMEWORK_CODEX_HOME" CODEX_SKILLS_HOME="$FRAMEWORK_SKILLS_HOME" \
  bash "$ROOT/scripts/framework-doctor.sh" --framework-only --skip-evidence --skip-prompt-input >/dev/null

printf 'framework doctor self-test passed\n'
