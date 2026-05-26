#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

[ $# -ge 1 ] || fail "usage: safe-commit.sh \"type(scope): message\""
message="$1"

ROOT="$(project_root)"
ensure_project_bootstrap "$ROOT"
cd "$ROOT"
git rev-parse --show-toplevel >/dev/null 2>&1 || fail "not in a git repository"

if [ -n "${2:-}" ] && [ "$2" = "--all" ]; then
  git add .
fi

git commit -m "$message"
git rev-parse --short HEAD
