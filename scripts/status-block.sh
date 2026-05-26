#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

[ $# -ge 4 ] || fail "usage: status-block.sh <state> <role> <model> <tier> [skills]"

state="$1"
role="$2"
model="$3"
tier="$4"
skills="${5:-none}"
memory_status="$(bash "$(framework_root)/scripts/memory-state.sh" status 2>/dev/null || true)"
memory_source="$(printf '%s\n' "$memory_status" | sed -n 's/^source=//p')"
memory_episodes="$(printf '%s\n' "$memory_status" | sed -n 's/^episode_count=//p')"

icon="⏺"
[ "$state" = "done" ] && icon="✅"
[ "$state" = "blocked" ] && icon="⛔"
memory_part=""
if [ -n "$memory_source" ]; then
  memory_part=" | memory:${memory_source}/${memory_episodes:-0}"
fi

if [ -n "$skills" ] && [ "$skills" != "none" ]; then
  printf '%s %s %s%s | 📚 %s\n' "$icon" "$(role_emoji "$role")" "$(route_badge "$role" "$model" "$tier")" "$memory_part" "$(plain_skill_list "$skills")"
else
  printf '%s %s %s%s\n' "$icon" "$(role_emoji "$role")" "$(route_badge "$role" "$model" "$tier")" "$memory_part"
fi
