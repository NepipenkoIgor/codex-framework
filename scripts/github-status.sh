#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

print_section "GitHub"

if ! has_command gh; then
  warn "gh CLI not installed"
  exit 0
fi

info "gh CLI: available"

if gh auth status >/dev/null 2>&1; then
  info "gh auth: valid"
else
  warn "gh auth: missing or invalid"
fi

if git rev-parse --show-toplevel >/dev/null 2>&1; then
  if gh repo view --json nameWithOwner,url >/dev/null 2>&1; then
    gh repo view --json nameWithOwner,url
  else
    warn "current repository is not linked or gh cannot read it"
  fi
else
  warn "not inside a git repository"
fi
