#!/bin/bash
set -euo pipefail

payload="$(cat)"
if command -v jq >/dev/null 2>&1; then
  command_text="$(printf '%s' "$payload" | jq -r '[.. | objects | to_entries[] | select(.key | test("^(cmd|command|shell_command|script)$")) | .value | if type == "array" then join(" ") else tostring end] | map(select(. != "null" and . != "")) | join("\\n")' 2>/dev/null)"
else
  command_text="$payload"
fi
command_scan="$(printf '%s' "$command_text" | tr '[:upper:]' '[:lower:]' | tr -d "'\\\"")"

block() {
  printf 'Codex Framework hook guard: %s\n' "$1" >&2
  exit 2
}

printf '%s\n' "$command_scan" | grep -Eq 'git[[:space:]]+commit([^[:alnum:]_-]|$).*--no-verify|--no-verify.*git[[:space:]]+commit' && block 'git commit --no-verify bypasses project policy'
printf '%s\n' "$command_scan" | grep -Eq 'git[[:space:]]+reset[[:space:]]+--hard|git[[:space:]]+clean[[:space:]].*-(fdx|xdf|dfx)' && block 'destructive git reset/clean requires explicit user intent'
printf '%s\n' "$command_scan" | grep -Eq 'rm[[:space:]].*-rf[[:space:]]+(/|\.git|~)|chmod[[:space:]]+-r[[:space:]]+777|curl[^|]*\|[[:space:]]*(sh|bash)|bash[[:space:]]+<\(curl' && block 'dangerous shell command pattern detected'

exit 0
