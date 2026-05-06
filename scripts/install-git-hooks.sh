#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

ROOT="${1:-$(project_root)}"
FRAMEWORK_ROOT="$(framework_root)"
HOOKS_DIR="$(ensure_project_git_hooks "$ROOT")"

cp "$FRAMEWORK_ROOT/templates/project/.githooks/pre-commit" "$HOOKS_DIR/pre-commit"
cp "$FRAMEWORK_ROOT/templates/project/.githooks/commit-msg" "$HOOKS_DIR/commit-msg"
chmod +x "$HOOKS_DIR/pre-commit" "$HOOKS_DIR/commit-msg"

if git -C "$ROOT" rev-parse --show-toplevel >/dev/null 2>&1; then
  current_hooks="$(git -C "$ROOT" config --local --get core.hooksPath 2>/dev/null || true)"
  if [ "$current_hooks" = ".githooks" ]; then
    git -C "$ROOT" config --local --unset core.hooksPath >/dev/null 2>&1 || true
  fi
  if [ -d "$ROOT/.githooks" ] && ! git -C "$ROOT" ls-files --error-unmatch .githooks >/dev/null 2>&1; then
    rm -rf "$ROOT/.githooks"
  fi
fi

printf '%s\n' "$HOOKS_DIR"
