#!/bin/bash
set -euo pipefail

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$HOOKS_DIR/../.." && pwd)"
. "$FRAMEWORK_ROOT/scripts/lib.sh"

hook_project_root() {
  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    git rev-parse --show-toplevel
  else
    pwd
  fi
}

hook_state_dir() {
  local root dir probe
  root="$(hook_project_root)"
  dir="$root/.codex/hooks"
  if mkdir -p "$dir" >/dev/null 2>&1; then
    probe="$dir/.write-test.$$"
    if touch "$probe" >/dev/null 2>&1; then
      rm -f "$probe"
      printf '%s\n' "$dir"
      return 0
    fi
  fi
  dir="/tmp/ai-codex-framework/$(basename "$root")/hooks"
  mkdir -p "$dir"
  printf '%s\n' "$dir"
}

hook_read_payload() {
  local file
  file="$(hook_state_dir)/last-payload.json"
  cat > "$file" || true
  printf '%s\n' "$file"
}

hook_json_query() {
  local file="$1"
  local query="$2"
  if has_command jq; then
    jq -r "$query" "$file" 2>/dev/null | awk 'NF { print; exit }'
  fi
}

hook_task_from_payload() {
  local file="$1"
  local value
  value="$(hook_json_query "$file" '.prompt // .user_prompt // .message // .input // .payload.prompt // .event.prompt // empty')"
  if [ -z "$value" ]; then
    value="$(sed -n 's/.*"prompt"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$file" | head -n 1)"
  fi
  printf '%s\n' "${value:-${CODEX_HOOK_TASK:-}}"
}

hook_tool_name_from_payload() {
  local file="$1"
  hook_json_query "$file" '.tool // .tool_name // .toolName // .name // .payload.tool // .event.tool // empty'
}

hook_command_text_from_payload() {
  local file="$1"
  local value
  if has_command jq; then
    value="$(
      jq -r '
        [
          .. | objects | to_entries[]
          | select(.key | test("^(cmd|command|shell_command|script)$"))
          | .value
          | if type == "array" then join(" ") else tostring end
        ]
        | map(select(. != "null" and . != ""))
        | join("\n")
      ' "$file" 2>/dev/null || true
    )"
  else
    value="$(sed -n 's/.*"cmd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p; s/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$file")"
  fi
  if [ -z "$value" ]; then
    value="$(sed -n '1,80p' "$file" 2>/dev/null || true)"
  fi
  printf '%s\n' "$value"
}

hook_record_event() {
  local event="$1"
  local detail="${2:-}"
  local file escaped_detail
  file="$(hook_state_dir)/events.jsonl"
  escaped_detail="$(printf '%s' "$detail" | tr '\n' ' ' | sed 's/\\/\\\\/g; s/"/\\"/g')"
  printf '{"ts":"%s","event":"%s","detail":%s}\n' \
    "$(timestamp_utc)" \
    "$event" \
    "\"$escaped_detail\"" \
    >> "$file" 2>/dev/null || true
}

hook_save_current_task() {
  local task="$1"
  [ -n "$task" ] || return 0
  printf '%s\n' "$task" > "$(hook_state_dir)/current-task.txt" 2>/dev/null || true
}

hook_current_task() {
  local file
  file="$(hook_state_dir)/current-task.txt"
  [ -f "$file" ] && sed -n '1p' "$file"
}

hook_enforce_mode() {
  case "${CODEX_HOOK_ENFORCE:-block}" in
    block|BLOCK|1|true|TRUE|yes|YES) printf 'block\n' ;;
    *) printf 'warn\n' ;;
  esac
}

hook_warn_or_block() {
  local message="$1"
  printf 'Codex Framework hook guard: %s\n' "$message" >&2
  if [ "$(hook_enforce_mode)" = "block" ]; then
    exit 2
  fi
  exit 0
}
