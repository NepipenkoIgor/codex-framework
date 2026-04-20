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

state_label="In Progress"
[ "$state" = "done" ] && state_label="Done"
[ "$state" = "blocked" ] && state_label="Blocked"

printf '%s %s %s~%s %s\n' "$icon" "$(role_emoji "$role")" "$(role_alias "$role")" "$(model_tag "$tier")" "$state_label"
printf '🤖 %s | Tier: %s\n' "$model" "$tier"
if [ -n "$skills" ] && [ "$skills" != "none" ]; then
  printf '📚 %s\n' "$(decorate_skill_list "$skills")"
fi
