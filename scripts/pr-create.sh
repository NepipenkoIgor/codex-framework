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

pr_publish_args=()
if [ -n "$BASE_BRANCH" ]; then
  pr_publish_args+=(--base "$BASE_BRANCH")
fi
bash "$(framework_root)/scripts/pr-publish.sh" "${pr_publish_args[@]}"

HEAD_BRANCH="$(current_branch)"
case "$HEAD_BRANCH" in
  main|master|develop|staging|release/*)
    fail "refusing to create PR from shared branch: $HEAD_BRANCH"
    ;;
  codex/*)
    fail "refusing to create PR from tool-revealing branch: $HEAD_BRANCH"
    ;;
esac

BASE_BRANCH="$(resolve_pr_base_branch "$BASE_BRANCH" || true)"
[ -n "$BASE_BRANCH" ] || fail "could not determine PR base branch"

if [ -z "$BODY_FILE" ]; then
  BODY_FILE="$(bash "$(framework_root)/scripts/pr-body.sh")"
fi
[ -f "$BODY_FILE" ] || fail "body file not found: $BODY_FILE"

if [ -z "$TITLE" ]; then
  TITLE="$(git log -1 --pretty=%s 2>/dev/null || true)"
fi
[ -n "$TITLE" ] || fail "could not infer PR title; pass --title"

existing_pr_info="$(gh pr view --json number,state,url --jq '[.number, .state, .url] | @tsv' 2>/dev/null || true)"
if [ -n "$existing_pr_info" ]; then
  IFS=$'\t' read -r existing_pr_number existing_pr_state existing_pr_url <<EOF
$existing_pr_info
EOF
  if [ "$existing_pr_state" = "OPEN" ]; then
    edit_cmd=(gh pr edit "$existing_pr_number" --title "$TITLE" --body-file "$BODY_FILE")
    edit_cmd+=(--base "$BASE_BRANCH")
    "${edit_cmd[@]}"
    gh pr view "$existing_pr_number" --json url --jq '.url'
    exit 0
  fi
fi

cmd=(gh pr create --title "$TITLE" --body-file "$BODY_FILE" --base "$BASE_BRANCH" --head "$HEAD_BRANCH")
if [ "$DRAFT" = true ]; then
  cmd+=(--draft)
fi

"${cmd[@]}"
