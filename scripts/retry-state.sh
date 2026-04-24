#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

usage() {
  cat <<EOF
usage: retry-state.sh <init|register|increment|set-model|get|clear> ...
EOF
}

STATE_FILE="$(project_codex_dir)/retry-state.json"
ensure_spec_root >/dev/null 2>&1 || true

require_jq() {
  has_command jq || fail "jq is required for retry-state"
}

cmd="${1:-}"
shift || true

case "$cmd" in
  init)
    require_jq
    conversation_id="${1:-$(date -u +"turn-%Y%m%dT%H%M%SZ")}"
    jq -n --arg id "$conversation_id" --arg ts "$(timestamp_utc)" '{conversation_id:$id, created_at:$ts, agents:{}}' > "$STATE_FILE"
    ;;
  register)
    require_jq
    agent_id="${1:-}"
    original_model="${2:-}"
    [ -n "$agent_id" ] && [ -n "$original_model" ] || fail "usage: retry-state.sh register <agent-id> <model>"
    [ -f "$STATE_FILE" ] || bash "$(framework_root)/scripts/retry-state.sh" init >/dev/null
    tmp="$(mktemp)"
    jq --arg id "$agent_id" --arg model "$original_model" '.agents[$id] = {original_model:$model,current_model:$model,retry_count:0,models_tried:[$model]}' "$STATE_FILE" > "$tmp"
    mv "$tmp" "$STATE_FILE"
    ;;
  increment)
    require_jq
    agent_id="${1:-}"
    [ -n "$agent_id" ] || fail "missing agent id"
    tmp="$(mktemp)"
    jq --arg id "$agent_id" '(.agents[$id].retry_count) += 1' "$STATE_FILE" > "$tmp"
    mv "$tmp" "$STATE_FILE"
    jq -r --arg id "$agent_id" '.agents[$id].retry_count' "$STATE_FILE"
    ;;
  set-model)
    require_jq
    agent_id="${1:-}"
    model="${2:-}"
    [ -n "$agent_id" ] && [ -n "$model" ] || fail "usage: retry-state.sh set-model <agent-id> <model>"
    tmp="$(mktemp)"
    jq --arg id "$agent_id" --arg model "$model" '(.agents[$id].current_model) = $model | (.agents[$id].models_tried) += [$model]' "$STATE_FILE" > "$tmp"
    mv "$tmp" "$STATE_FILE"
    ;;
  get)
    [ -f "$STATE_FILE" ] || fail "retry state not initialized"
    cat "$STATE_FILE"
    ;;
  clear)
    rm -f "$STATE_FILE"
    ;;
  *)
    usage
    exit 1
    ;;
esac
