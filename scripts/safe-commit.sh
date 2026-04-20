#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

[ $# -ge 1 ] || fail "usage: safe-commit.sh \"type(scope): message\""
message="$1"

if ! conventional_commit_valid "$message"; then
  fail "invalid conventional commit message: $message"
fi

case "$message" in
  *Co-Authored-By:*|*Generated\ with*|*AI\ attribution*|*🤖*)
    fail "commit message contains forbidden attribution"
    ;;
esac

ROOT="$(project_root)"
ensure_project_bootstrap "$ROOT"
cd "$ROOT"
git rev-parse --show-toplevel >/dev/null 2>&1 || fail "not in a git repository"

git add -u
if [ -n "${2:-}" ] && [ "$2" = "--all" ]; then
  git add .
fi

git diff --cached --quiet && fail "nothing staged for commit"

git commit -m "$message"
git rev-parse --short HEAD
