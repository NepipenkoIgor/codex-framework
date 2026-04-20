#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

ROOT="$(project_root)"
ensure_project_bootstrap "$ROOT"
load_project_commands
cd "$ROOT"

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
  esac

  print_section "Git"
  git status --short || true
  git diff --stat HEAD || true
fi

if [ ! -f "$ROOT/CODEX.md" ]; then
  warn "project CODEX.md missing"
fi

if [ -n "${LINT_CMD:-}" ]; then
  run_named_command "lint" "$LINT_CMD"
fi
if [ -n "${TEST_CMD:-}" ]; then
  run_named_command "tests" "$TEST_CMD"
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
