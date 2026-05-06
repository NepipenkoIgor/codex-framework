#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

ROOT="$(project_root)"
ensure_project_bootstrap "$ROOT"
load_project_commands
load_repo_intelligence

print_section "Project"
info "root: $ROOT"
info "branch: $(current_branch)"
info "stack: $RI_STACK"
info "domain_hints: $RI_DOMAIN_HINTS"
info "primary_framework: $RI_PRIMARY_FRAMEWORK"

print_section "Framework"
if [ -f "$ROOT/CODEX.md" ]; then
  info "project CODEX.md: present"
else
  warn "project CODEX.md missing"
fi

if [ -f "$(project_commands_file)" ]; then
  info "project commands: present"
else
  warn "project commands missing at $(project_commands_file)"
fi

ensure_spec_root
info "spec root: $(spec_root)"

memory_dir="$(bash "$(framework_root)/scripts/memory-state.sh" init 2>/dev/null || true)"
if [ -n "$memory_dir" ]; then
  info "memory root: $memory_dir"
else
  warn "memory root unavailable"
fi

print_section "Git"
if git rev-parse --show-toplevel >/dev/null 2>&1; then
  if git_has_changes; then
    warn "working tree has changes"
    git status --short
  else
    info "working tree clean"
  fi
else
  warn "not inside a git repository"
fi

print_section "Commands"
for name in PROJECT_COMMANDS_MODE PACKAGE_RUNNER PACKAGE_EXEC TEST_CMD LINT_CMD BUILD_CMD DEV_CMD; do
  value="${!name:-}"
  if [ -n "$value" ]; then
    info "$name=$value"
  fi
done
