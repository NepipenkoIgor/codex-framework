#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

usage() {
  cat <<EOF
usage: pr-publish.sh [--base <branch>]
EOF
}

BASE_BRANCH=""

while [ $# -gt 0 ]; do
  case "$1" in
    --base)
      BASE_BRANCH="${2:-}"
      shift 2
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

branch="$(current_branch)"
case "$branch" in
  main|master|develop|staging|release/*)
    fail "refusing to publish shared branch: $branch"
    ;;
  codex/*)
    fail "refusing to publish tool-revealing branch: $branch"
    ;;
esac

base="$(resolve_pr_base_branch "$BASE_BRANCH" || true)"
[ -n "$base" ] || fail "could not determine the PR base branch"

print_section "Branch"
info "head: $branch"
info "base: $base"

print_section "Publish"
sync_branch_for_pr "$base"
bash "$(framework_root)/scripts/pr-ready.sh" --base "$base"
git push --force-with-lease -u origin "$branch"

report_file="$(run_root)/latest-pr-publish.env"
{
  printf 'timestamp=%q\n' "$(timestamp_utc)"
  printf 'branch=%q\n' "$branch"
  printf 'base=%q\n' "$base"
} > "$report_file"

print_section "Result"
info "branch published"
info "report: $report_file"
