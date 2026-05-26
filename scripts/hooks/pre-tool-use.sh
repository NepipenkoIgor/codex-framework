#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

payload_file="$(hook_read_payload)"
tool="$(hook_tool_name_from_payload "$payload_file")"
command_text="$(hook_command_text_from_payload "$payload_file")"

hook_record_event "PreToolUse" "${tool:-unknown}"

tool_lc="$(printf '%s' "$tool" | tr '[:upper:]' '[:lower:]')"
command_lc="$(printf '%s' "$command_text" | tr '[:upper:]' '[:lower:]')"

case "$tool_lc" in
  *bash*|*shell*|*exec*|*terminal*|"")
    if printf '%s\n' "$command_lc" | grep -Eq 'git[[:space:]]+commit([^[:alnum:]_-]|$).*--no-verify|--no-verify.*git[[:space:]]+commit'; then
      hook_warn_or_block "git commit --no-verify bypasses project policy"
    fi
    if printf '%s\n' "$command_lc" | grep -Eq 'git[[:space:]]+reset[[:space:]]+--hard|git[[:space:]]+clean[[:space:]].*-fdx'; then
      hook_warn_or_block "destructive git reset/clean requires explicit user intent"
    fi
    if printf '%s\n' "$command_lc" | grep -Eq 'rm[[:space:]].*-rf[[:space:]]+(/|\.git|~)|chmod[[:space:]]+-r[[:space:]]+777|curl[^\n|]*\|[[:space:]]*(sh|bash)|bash[[:space:]]+<\(curl'; then
      hook_warn_or_block "dangerous shell command pattern detected"
    fi
    ;;
esac

exit 0

