#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

usage() {
  cat <<EOF
usage: handoff-state.sh <init|register|status|decision|blocker|get|clear> ...
EOF
}

ROOT="$(project_root)"
STATE_DIR="$(project_codex_dir)/handoffs"
mkdir -p "$STATE_DIR"

state_file() {
  printf '%s/%s.json\n' "$STATE_DIR" "$1"
}

require_jq() {
  has_command jq || fail "jq is required for handoff-state"
}

cmd="${1:-}"
shift || true

case "$cmd" in
  init)
    require_jq
    task_id="${1:-}"
    [ -n "$task_id" ] || fail "missing task id"
    jq -n --arg id "$task_id" --arg ts "$(timestamp_utc)" '{task_id:$id, created_at:$ts, agents:[]}' > "$(state_file "$task_id")"
    ;;
  register)
    require_jq
    task_id="${1:-}"
    agent="${2:-}"
    [ -n "$task_id" ] && [ -n "$agent" ] || fail "usage: register <task-id> <agent>"
    file="$(state_file "$task_id")"
    [ -f "$file" ] || bash "$(framework_root)/scripts/handoff-state.sh" init "$task_id" >/dev/null
    tmp="$(mktemp)"
    jq --arg agent "$agent" '.agents += [{agent:$agent,status:"running",decisions:[],blockers:[]}]' "$file" > "$tmp"
    mv "$tmp" "$file"
    ;;
  status)
    require_jq
    task_id="${1:-}"
    agent="${2:-}"
    status="${3:-}"
    [ -n "$task_id" ] && [ -n "$agent" ] && [ -n "$status" ] || fail "usage: status <task-id> <agent> <status>"
    file="$(state_file "$task_id")"
    tmp="$(mktemp)"
    jq --arg agent "$agent" --arg status "$status" '(.agents[] | select(.agent == $agent) | .status) = $status' "$file" > "$tmp"
    mv "$tmp" "$file"
    ;;
  decision|blocker)
    require_jq
    task_id="${1:-}"
    agent="${2:-}"
    shift 2 || true
    text="$*"
    [ -n "$task_id" ] && [ -n "$agent" ] && [ -n "$text" ] || fail "usage: $cmd <task-id> <agent> <text>"
    key="decisions"
    [ "$cmd" = "blocker" ] && key="blockers"
    file="$(state_file "$task_id")"
    tmp="$(mktemp)"
    jq --arg agent "$agent" --arg text "$text" --arg key "$key" '(.agents[] | select(.agent == $agent) | .[$key]) += [$text]' "$file" > "$tmp"
    mv "$tmp" "$file"
    ;;
  get)
    task_id="${1:-}"
    [ -n "$task_id" ] || fail "missing task id"
    cat "$(state_file "$task_id")"
    ;;
  clear)
    task_id="${1:-}"
    [ -n "$task_id" ] || fail "missing task id"
    rm -f "$(state_file "$task_id")"
    ;;
  *)
    usage
    exit 1
    ;;
esac
