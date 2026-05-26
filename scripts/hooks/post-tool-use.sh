#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

payload_file="$(hook_read_payload)"
tool="$(hook_tool_name_from_payload "$payload_file")"
root="$(hook_project_root)"

cd "$root"
hook_record_event "PostToolUse" "${tool:-unknown}"

changed="$(git_changed_files 2>/dev/null || true)"
[ -n "$changed" ] || exit 0

{
  printf 'changed_count=%s\n' "$(printf '%s\n' "$changed" | awk 'NF' | wc -l | tr -d ' ')"
  printf 'changed_files<<EOF\n%s\nEOF\n' "$changed"
} > "$(hook_state_dir)/last-change-state.env" 2>/dev/null || true

exit 0

