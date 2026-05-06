#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

usage() {
  cat <<EOF
usage: memory-state.sh <init|status|context|search|add-episode|add-decision|compact|prune|get> ...

commands:
  init
  status
  context [task text]
  search <query>
  add-episode --task <text> [--summary <text>] [--files <csv>] [--verification <csv>] [--tags <csv>]
  add-decision <text>
  compact [keep-count]
  prune [keep-count]
  get
EOF
}

ROOT="$(project_root)"
FRAMEWORK_ROOT="$(framework_root)"
MEMORY_DIR="$(memory_root)"
PROJECT_FILE="$MEMORY_DIR/project.md"
PREFERENCES_FILE="$MEMORY_DIR/preferences.md"
DECISIONS_FILE="$MEMORY_DIR/decisions.local.md"
EPISODES_FILE="$MEMORY_DIR/episodes.jsonl"
SUMMARIES_DIR="$MEMORY_DIR/summaries"

require_jq() {
  has_command jq || fail "jq is required for structured memory writes"
}

ensure_memory_files() {
  mkdir -p "$MEMORY_DIR" "$SUMMARIES_DIR"
  touch "$EPISODES_FILE"

  if [ ! -f "$PROJECT_FILE" ]; then
    load_repo_intelligence
    cat > "$PROJECT_FILE" <<EOF
# Project Memory

Generated from repo intelligence. Edit this file for stable local project facts that should be available at session start.

## Repo Intelligence

- Root: $ROOT
- Primary framework: $RI_PRIMARY_FRAMEWORK
- Stack: $RI_STACK
- Features: $RI_FEATURES
- Policy: $RI_POLICY
- Conventions: $RI_CONVENTIONS
- Domain hints: $RI_DOMAIN_HINTS

## Stable Notes

- Add durable repo-specific notes here.
EOF
  fi

  if [ ! -f "$PREFERENCES_FILE" ]; then
    cat > "$PREFERENCES_FILE" <<EOF
# Operator Preferences

- Add local workflow preferences here.
EOF
  fi

  if [ ! -f "$DECISIONS_FILE" ]; then
    cat > "$DECISIONS_FILE" <<EOF
# Local Decisions

Record local architecture, workflow, and verification decisions that should influence future sessions.
Use tracked ADRs or project docs for decisions the whole team should share.
EOF
  fi
}

print_limited_file() {
  local title="$1"
  local file="$2"
  local lines="${3:-80}"
  printf '## %s\n' "$title"
  if [ -s "$file" ]; then
    sed -n "1,${lines}p" "$file"
  else
    printf 'none\n'
  fi
  printf '\n'
}

query_pattern() {
  local query="$1"
  printf '%s\n' "$query" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -cs '[:alnum:]_-' '\n' \
    | awk 'length($0) >= 4 { print }' \
    | awk '!seen[$0]++' \
    | head -n 8 \
    | paste -sd '|' -
}

search_episodes() {
  local query="${1:-}"
  local pattern
  [ -s "$EPISODES_FILE" ] || return 0
  pattern="$(query_pattern "$query")"
  if [ -n "$pattern" ]; then
    if has_command rg; then
      rg -i "$pattern" "$EPISODES_FILE" | tail -n 5 || true
    else
      grep -Ei "$pattern" "$EPISODES_FILE" | tail -n 5 || true
    fi
  else
    tail -n 3 "$EPISODES_FILE"
  fi
}

print_context() {
  local task="${1:-}"
  ensure_memory_files
  print_limited_file "Project Memory" "$PROJECT_FILE" 80
  print_limited_file "Operator Preferences" "$PREFERENCES_FILE" 40
  print_limited_file "Local Decisions" "$DECISIONS_FILE" 60
  printf '## Relevant Episodes\n'
  matches="$(search_episodes "$task")"
  if [ -n "$matches" ]; then
    printf '%s\n' "$matches"
  else
    printf 'none\n'
  fi
}

json_array_from_csv() {
  local csv="$1"
  jq -Rn --arg csv "$csv" '
    $csv
    | split(",")
    | map(gsub("^\\s+|\\s+$"; ""))
    | map(select(length > 0))
  '
}

cmd="${1:-}"
shift || true

case "$cmd" in
  init)
    ensure_memory_files
    printf '%s\n' "$MEMORY_DIR"
    ;;
  status)
    ensure_memory_files
    printf 'memory_dir=%s\n' "$MEMORY_DIR"
    printf 'project=%s\n' "$PROJECT_FILE"
    printf 'preferences=%s\n' "$PREFERENCES_FILE"
    printf 'decisions=%s\n' "$DECISIONS_FILE"
    printf 'episodes=%s\n' "$EPISODES_FILE"
    printf 'episode_count=%s\n' "$(wc -l < "$EPISODES_FILE" | tr -d ' ')"
    ;;
  context)
    print_context "$*"
    ;;
  search)
    ensure_memory_files
    [ $# -ge 1 ] || fail "usage: search <query>"
    search_episodes "$*" || true
    ;;
  add-episode)
    require_jq
    ensure_memory_files
    task=""
    summary=""
    files=""
    verification=""
    tags=""
    while [ $# -gt 0 ]; do
      case "$1" in
        --task) task="${2:-}"; shift 2 ;;
        --summary) summary="${2:-}"; shift 2 ;;
        --files) files="${2:-}"; shift 2 ;;
        --verification) verification="${2:-}"; shift 2 ;;
        --tags) tags="${2:-}"; shift 2 ;;
        *) fail "unknown add-episode argument: $1" ;;
      esac
    done
    [ -n "$task" ] || fail "add-episode requires --task"
    jq -cn \
      --arg id "$(date -u +"episode-%Y%m%dT%H%M%SZ")" \
      --arg created_at "$(timestamp_utc)" \
      --arg task "$task" \
      --arg summary "$summary" \
      --argjson files "$(json_array_from_csv "$files")" \
      --argjson verification "$(json_array_from_csv "$verification")" \
      --argjson tags "$(json_array_from_csv "$tags")" \
      '{id:$id,created_at:$created_at,task:$task,summary:$summary,files:$files,verification:$verification,tags:$tags}' \
      >> "$EPISODES_FILE"
    printf '%s\n' "$EPISODES_FILE"
    ;;
  add-decision)
    ensure_memory_files
    [ $# -ge 1 ] || fail "usage: add-decision <text>"
    printf '\n- %s: %s\n' "$(timestamp_utc)" "$*" >> "$DECISIONS_FILE"
    printf '%s\n' "$DECISIONS_FILE"
    ;;
  compact|prune)
    ensure_memory_files
    keep_count="${1:-200}"
    case "$keep_count" in
      ''|*[!0-9]*) fail "keep-count must be a number" ;;
    esac
    total="$(wc -l < "$EPISODES_FILE" | tr -d ' ')"
    if [ "$total" -le "$keep_count" ]; then
      printf 'kept %s episodes; no pruning needed\n' "$total"
      exit 0
    fi
    archive="$SUMMARIES_DIR/episodes-before-$(date -u +"%Y%m%dT%H%M%SZ").jsonl"
    head -n "$((total - keep_count))" "$EPISODES_FILE" > "$archive"
    tail -n "$keep_count" "$EPISODES_FILE" > "$EPISODES_FILE.tmp"
    mv "$EPISODES_FILE.tmp" "$EPISODES_FILE"
    printf 'archived %s episodes to %s\n' "$((total - keep_count))" "$archive"
    ;;
  get)
    ensure_memory_files
    printf '%s\n' "$MEMORY_DIR"
    ;;
  ''|-h|--help|help)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
