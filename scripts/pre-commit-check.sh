#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

ROOT="$(project_root)"
cd "$ROOT"

print_section "Pre-Commit Checks"

if ! bash "$(framework_root)/scripts/guard-scan.sh" --staged; then
  fail "guard scan failed"
fi

if [ -n "$(git diff --cached --name-only | grep -E '\.(ts|tsx|js|jsx|py|cs|go|md|sh|ya?ml)$' || true)" ]; then
  bash "$(framework_root)/scripts/post-change-check.sh"
fi

info "pre-commit checks passed"
