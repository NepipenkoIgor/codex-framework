#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

ensure_project_bootstrap "$(project_root)"
ensure_spec_root

if [ $# -gt 0 ]; then
  spec_file="$(spec_root)/$1/spec.md"
  [ -f "$spec_file" ] || fail "spec not found: $spec_file"
else
  spec_file="$(active_spec_file || true)"
  [ -n "$spec_file" ] || fail "no active spec found under $(spec_root)"
fi

print_section "Spec"
info "file: $spec_file"
title="$(grep -m1 '^#' "$spec_file" 2>/dev/null | sed 's/^# *//' || true)"
[ -n "$title" ] && info "title: $title"
visual="$(grep -m1 '^Visual:' "$spec_file" 2>/dev/null | sed 's/^Visual:[[:space:]]*//' || true)"
[ -n "$visual" ] && info "visual: $visual"

read -r done failed pending <<EOF
$(spec_counts "$spec_file")
EOF

print_section "Counts"
info "done=$done"
info "failed=$failed"
info "pending=$pending"

print_section "Next"
if [ "$failed" -gt 0 ]; then
  info "next action: fix failing rows"
elif [ "$pending" -gt 0 ] && [ "$visual" = "yes" ]; then
  info "next action: run browser verification"
elif [ "$pending" -gt 0 ]; then
  info "next action: implement pending rows"
else
  info "next action: ready for review or PR"
fi
