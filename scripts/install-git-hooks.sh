#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

ROOT="${1:-$(project_root)}"
FRAMEWORK_ROOT="$(framework_root)"
HOOKS_DIR="$ROOT/.githooks"

ensure_project_git_hooks "$ROOT"
mkdir -p "$HOOKS_DIR"

cp "$FRAMEWORK_ROOT/templates/project/.githooks/pre-commit" "$HOOKS_DIR/pre-commit"
cp "$FRAMEWORK_ROOT/templates/project/.githooks/commit-msg" "$HOOKS_DIR/commit-msg"
chmod +x "$HOOKS_DIR/pre-commit" "$HOOKS_DIR/commit-msg"

if git -C "$ROOT" rev-parse --show-toplevel >/dev/null 2>&1; then
  git -C "$ROOT" config --local core.hooksPath .githooks >/dev/null 2>&1 || true
fi

printf '%s\n' "$HOOKS_DIR"
