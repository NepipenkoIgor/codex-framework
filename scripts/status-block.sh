#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

[ $# -ge 4 ] || fail "usage: status-block.sh <state> <role> <model> <tier> [skills]"

state="$1"
role="$2"
model="$3"
tier="$4"
skills="${5:-none}"

icon="⏺"
[ "$state" = "done" ] && icon="✅"
[ "$state" = "blocked" ] && icon="⛔"

if [ -n "$skills" ] && [ "$skills" != "none" ]; then
  printf '%s %s %s | 📚 %s\n' "$icon" "$(role_emoji "$role")" "$(route_badge "$role" "$model" "$tier")" "$(plain_skill_list "$skills")"
else
  printf '%s %s %s\n' "$icon" "$(role_emoji "$role")" "$(route_badge "$role" "$model" "$tier")"
fi
