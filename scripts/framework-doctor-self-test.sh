#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/codex-framework-doctor-eval.XXXXXX")"
FRAMEWORK_CODEX_HOME="$FIXTURE/.codex"
FRAMEWORK_SKILLS_HOME="$FIXTURE/.agents/skills"
trap 'rm -rf -- "$FIXTURE"' EXIT

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
