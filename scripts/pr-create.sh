#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

usage() {
  cat <<EOF
usage: pr-create.sh [--title "<title>"] [--body-file <file>] [--base <branch>] [--draft]
EOF
}

TITLE=""
BODY_FILE=""
BASE_BRANCH=""
DRAFT=false

while [ $# -gt 0 ]; do
  case "$1" in
    --title)
      TITLE="${2:-}"
      shift 2
      ;;
    --body-file)
      BODY_FILE="${2:-}"
      shift 2
      ;;
    --base)
      BASE_BRANCH="${2:-}"
      shift 2
      ;;
    --draft)
      DRAFT=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

ROOT="$(project_root)"
ensure_project_bootstrap "$ROOT"
cd "$ROOT"

git rev-parse --show-toplevel >/dev/null 2>&1 || fail "not inside a git repository"
has_command gh || fail "gh CLI is required"
gh auth status >/dev/null 2>&1 || fail "gh auth is required"

if [ -z "$BODY_FILE" ]; then
  BODY_FILE="$(bash "$(framework_root)/scripts/pr-body.sh")"
fi
[ -f "$BODY_FILE" ] || fail "body file not found: $BODY_FILE"

if [ -z "$TITLE" ]; then
  TITLE="$(git log -1 --pretty=%s 2>/dev/null || true)"
fi
[ -n "$TITLE" ] || fail "could not infer PR title; pass --title"

cmd=(gh pr create --title "$TITLE" --body-file "$BODY_FILE")
if [ -n "$BASE_BRANCH" ]; then
  cmd+=(--base "$BASE_BRANCH")
fi
if [ "$DRAFT" = true ]; then
  cmd+=(--draft)
fi

"${cmd[@]}"
