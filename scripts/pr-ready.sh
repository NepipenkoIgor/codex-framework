#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

ROOT="$(project_root)"
ensure_project_bootstrap "$ROOT"
load_project_commands
cd "$ROOT"

BASE_BRANCH=""
while [ $# -gt 0 ]; do
  case "$1" in
    --base)
      BASE_BRANCH="${2:-}"
      shift 2
      ;;
    -h|--help)
      cat <<EOF
usage: pr-ready.sh [--base <branch>]
EOF
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

print_section "Branch"
branch="$(current_branch)"
info "$branch"
if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  warn "not inside a git repository"
else
  case "$branch" in
    main|master|develop|staging|release/*)
      fail "refusing PR readiness on shared branch: $branch"
      ;;
    codex/*)
      fail "refusing PR readiness on tool-revealing branch: $branch"
      ;;
  esac

  print_section "Git"
  git status --short || true
  git diff --stat HEAD || true
fi

if [ ! -f "$ROOT/CODEX.md" ]; then
  warn "project CODEX.md missing"
fi

report_file="$(run_root)/latest-pr-ready.env"
{
  printf 'timestamp=%q\n' "$(timestamp_utc)"
  printf 'branch=%q\n' "$branch"
  printf 'base=%q\n' "$(resolve_pr_base_branch "$BASE_BRANCH" || true)"
} > "$report_file"

record_check() {
  local name="$1"
  local status="$2"
  local cmd="${3:-}"
  {
    printf 'check_%s_status=%q\n' "$name" "$status"
    printf 'check_%s_cmd=%q\n' "$name" "$cmd"
  } >> "$report_file"
}

if [ -n "${LINT_CMD:-}" ]; then
  if run_named_command "lint" "$LINT_CMD"; then
    record_check "lint" "passed" "$LINT_CMD"
  else
    record_check "lint" "failed" "$LINT_CMD"
    fail "lint failed"
  fi
else
  record_check "lint" "not_configured" ""
fi
if [ -n "${TEST_CMD:-}" ]; then
  if run_named_command "tests" "$TEST_CMD"; then
    record_check "tests" "passed" "$TEST_CMD"
  else
    record_check "tests" "failed" "$TEST_CMD"
    fail "tests failed"
  fi
else
  record_check "tests" "not_configured" ""
fi
if [ -n "${BUILD_CMD:-}" ]; then
  if run_named_command "build" "$BUILD_CMD"; then
    record_check "build" "passed" "$BUILD_CMD"
  else
    record_check "build" "failed" "$BUILD_CMD"
    fail "build failed"
  fi
else
  record_check "build" "not_configured" ""
fi

print_section "Spec"
spec="$(active_spec_file 2>/dev/null || true)"
if [ -n "$spec" ]; then
  read -r done failed pending <<EOF
$(spec_counts "$spec")
EOF
  info "active spec: $spec"
  info "done=$done failed=$failed pending=$pending"
  if [ "$failed" -gt 0 ] || [ "$pending" -gt 0 ]; then
    warn "active spec is not fully complete"
  fi
else
  info "no active spec found"
fi

print_section "Result"
info "PR readiness checks finished"
info "publish with: codex-fw pr-publish"
info "report: $report_file"
