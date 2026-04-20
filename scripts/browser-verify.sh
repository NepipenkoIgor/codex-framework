#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

ensure_project_bootstrap "$(project_root)"
ensure_spec_root
spec_file="${1:-}"
if [ -z "$spec_file" ]; then
  spec_file="$(active_spec_file || true)"
fi

[ -n "$spec_file" ] || fail "no active spec found"
[ -f "$spec_file" ] || fail "spec file not found: $spec_file"

visual="$(grep -m1 '^Visual:' "$spec_file" 2>/dev/null | sed 's/^Visual:[[:space:]]*//' || true)"
if [ "$visual" != "yes" ]; then
  info "spec has no visual verification requirement"
  exit 0
fi

read -r _done failed pending <<EOF
$(spec_counts "$spec_file")
EOF

print_section "Spec"
info "$spec_file"
info "failed=$failed pending=$pending"

print_section "Local URL"
if url="$(detect_local_url || true)"; then
  info "$url"
else
  load_project_commands
  if [ -n "${DEV_CMD:-}" ]; then
    warn "no live dev server detected"
    info "configured dev command: $DEV_CMD"
  else
    fail "no live dev server detected and DEV_CMD not configured"
  fi
fi

print_section "Next"
info "run browser verification against the live URL and update the spec rows"
