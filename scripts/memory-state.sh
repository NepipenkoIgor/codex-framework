#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

usage() {
  cat <<EOF
usage: memory-state.sh <init|status|doctor|context|search|refresh-project|start-session|finish-session|add-episode|add-decision|compact|prune|cleanup-old-stores|get> ...

commands:
  init
  status
  doctor
  context [task text]
  search <query>
  refresh-project [task text]
  start-session --task <text> [--surface <cli|desktop>]
  finish-session --task <text> [--summary <text>] [--files <csv>] [--verification <csv>] [--tags <csv>] [--surface <cli|desktop>]
  add-episode --task <text> [--summary <text>] [--files <csv>] [--verification <csv>] [--tags <csv>]
  add-decision <text>
  compact [keep-count]
  prune [keep-count]
  cleanup-old-stores [--delete]
  get
EOF
}

ROOT="$(project_root)"
FRAMEWORK_ROOT="$(framework_root)"
MEMORY_DIR="$(memory_root)"
CANONICAL_MEMORY_DIR="$ROOT/.codex-memory"
OLD_MEMORY_DIR="$(project_codex_dir)/memory"
TMP_MEMORY_DIR="/tmp/ai-codex-framework/$(basename "$ROOT")/memory"
PROJECT_FILE="$MEMORY_DIR/project.md"
PREFERENCES_FILE="$MEMORY_DIR/preferences.md"
DECISIONS_FILE="$MEMORY_DIR/decisions.local.md"
EPISODES_FILE="$MEMORY_DIR/episodes.jsonl"
SUMMARIES_DIR="$MEMORY_DIR/summaries"
SESSIONS_DIR="$MEMORY_DIR/sessions"
LAST_CONTEXT_FILE="$MEMORY_DIR/.last-context-loaded"
LAST_EPISODE_FILE="$MEMORY_DIR/.last-episode-recorded"
ACTIVE_SESSION_FILE="$MEMORY_DIR/.active-session"
MEMORY_MIGRATED=0

require_jq() {
  has_command jq || fail "jq is required for structured memory writes"
}

ensure_gitignore_entry() {
  local entry="$1"
  local gitignore="$ROOT/.gitignore"

  if [ ! -f "$gitignore" ]; then
    touch "$gitignore" 2>/dev/null || return 0
  fi

  grep -qxF "$entry" "$gitignore" 2>/dev/null && return 0
  printf '%s\n' "$entry" >> "$gitignore" 2>/dev/null || true
}

ensure_memory_gitignore() {
  ensure_gitignore_entry '/.codex/memory/'
  ensure_gitignore_entry '/.codex-memory/'
}

stable_notes_block() {
  if [ -s "$PROJECT_FILE" ] && grep -q '^## Stable Notes' "$PROJECT_FILE"; then
    sed -n '/^## Stable Notes/,$p' "$PROJECT_FILE"
  else
    cat <<EOF
## Stable Notes

- Add durable repo-specific notes here.
EOF
  fi
}

write_project_memory_file() {
  local task="${1:-}"
  local stable_notes
  stable_notes="$(stable_notes_block)"
  load_repo_intelligence "$task"
  cat > "$PROJECT_FILE" <<EOF
# Project Memory

Generated from repo intelligence. Edit Stable Notes for durable local project facts that should be available at session start.
Run \`codex-fw memory refresh-project\` after meaningful stack, tooling, or convention changes.

## Repo Intelligence

- Root: $ROOT
- Refreshed at: $(timestamp_utc)
- Primary framework: $RI_PRIMARY_FRAMEWORK
- Stack: $RI_STACK
- Features: $RI_FEATURES
- Policy: $RI_POLICY
- Conventions: $RI_CONVENTIONS
- Domain hints: $RI_DOMAIN_HINTS

$stable_notes
EOF
}

merge_episode_file() {
  local source_file="$1"
  local before after
  [ -s "$source_file" ] || return 0

  if [ ! -s "$EPISODES_FILE" ]; then
    cp "$source_file" "$EPISODES_FILE" 2>/dev/null || return 0
    MEMORY_MIGRATED=1
    return 0
  fi

  tmp_file="$EPISODES_FILE.tmp.$$"
  before="$(wc -l < "$EPISODES_FILE" | tr -d ' ')"
  cat "$EPISODES_FILE" "$source_file" 2>/dev/null \
    | awk '!seen[$0]++' > "$tmp_file" \
    && mv "$tmp_file" "$EPISODES_FILE" \
    || rm -f "$tmp_file"
  after="$(wc -l < "$EPISODES_FILE" | tr -d ' ')"
  if [ "$after" -gt "$before" ]; then
    MEMORY_MIGRATED=1
  fi
}

copy_missing_memory_file() {
  local source_file="$1"
  local target_file="$2"
  if [ ! -s "$target_file" ] && [ -s "$source_file" ]; then
    cp "$source_file" "$target_file" 2>/dev/null && MEMORY_MIGRATED=1
  fi
}

copy_missing_summaries() {
  local source_dir="$1/summaries"
  [ -d "$source_dir" ] || return 0
  mkdir -p "$SUMMARIES_DIR"
  for source_file in "$source_dir"/*; do
    [ -f "$source_file" ] || continue
    target_file="$SUMMARIES_DIR/$(basename "$source_file")"
    if [ ! -e "$target_file" ]; then
      cp "$source_file" "$target_file" 2>/dev/null && MEMORY_MIGRATED=1
    fi
  done
}

try_migrate_memory_from() {
  local source_dir="$1"
  [ -d "$source_dir" ] || return 0
  [ "$source_dir" != "$MEMORY_DIR" ] || return 0

  copy_missing_memory_file "$source_dir/project.md" "$PROJECT_FILE"
  copy_missing_memory_file "$source_dir/preferences.md" "$PREFERENCES_FILE"
  copy_missing_memory_file "$source_dir/decisions.local.md" "$DECISIONS_FILE"
  merge_episode_file "$source_dir/episodes.jsonl"
  copy_missing_summaries "$source_dir"
}

ensure_memory_migrated() {
  try_migrate_memory_from "$OLD_MEMORY_DIR"
  try_migrate_memory_from "$TMP_MEMORY_DIR"
}

memory_source_label() {
  if [ -n "${CODEX_MEMORY_DIR:-}" ] && [ "$MEMORY_DIR" = "$CODEX_MEMORY_DIR" ]; then
    printf 'override\n'
  elif [ "$MEMORY_DIR" = "$CANONICAL_MEMORY_DIR" ]; then
    printf 'canonical\n'
  elif [ "$MEMORY_DIR" = "$OLD_MEMORY_DIR" ]; then
    printf 'old_store\n'
  elif [ "$MEMORY_DIR" = "$TMP_MEMORY_DIR" ]; then
    printf 'scratch\n'
  else
    printf 'custom\n'
  fi
}

ensure_memory_files() {
  ensure_memory_gitignore
  mkdir -p "$MEMORY_DIR" "$SUMMARIES_DIR" "$SESSIONS_DIR"
  touch "$EPISODES_FILE"
  ensure_memory_migrated

  if [ ! -f "$PROJECT_FILE" ]; then
    write_project_memory_file
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

write_memory_marker() {
  local file="$1"
  local kind="$2"
  local detail="${3:-}"

  {
    printf 'kind=%s\n' "$kind"
    printf 'at=%s\n' "$(timestamp_utc)"
    printf 'root=%s\n' "$ROOT"
    if [ -n "$detail" ]; then
      printf 'detail=%s\n' "$detail"
    fi
  } > "$file" 2>/dev/null || true
}

session_id_from_task() {
  local task="$1"
  local slug
  slug="$(printf '%s' "$task" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | sed 's/^-//; s/-$//' | cut -c1-48)"
  [ -n "$slug" ] || slug="session"
  printf '%s-%s\n' "$(date -u +"%Y%m%dT%H%M%SZ")" "$slug"
}

active_session_value() {
  [ -f "$ACTIVE_SESSION_FILE" ] && sed -n 's/^id=//p' "$ACTIVE_SESSION_FILE" | tail -n 1
}

start_memory_session() {
  local task="" surface="desktop" id file
  while [ $# -gt 0 ]; do
    case "$1" in
      --task) task="${2:-}"; shift 2 ;;
      --surface) surface="${2:-}"; shift 2 ;;
      *) fail "unknown start-session argument: $1" ;;
    esac
  done
  [ -n "$task" ] || fail "start-session requires --task"
  ensure_memory_files
  id="$(session_id_from_task "$task")"
  file="$SESSIONS_DIR/$id.env"
  {
    printf 'id=%s\n' "$id"
    printf 'task=%s\n' "$task"
    printf 'surface=%s\n' "$surface"
    printf 'started_at=%s\n' "$(timestamp_utc)"
    printf 'status=active\n'
  } > "$file"
  cp "$file" "$ACTIVE_SESSION_FILE" 2>/dev/null || true
  write_memory_marker "$LAST_CONTEXT_FILE" "context" "$task"
  printf 'session_id=%s\n' "$id"
  printf 'memory_dir=%s\n' "$MEMORY_DIR"
  printf 'source=%s\n' "$(memory_source_label)"
}

finish_memory_session() {
  local task="" summary="" files="" verification="" tags="session" surface="desktop" id file
  while [ $# -gt 0 ]; do
    case "$1" in
      --task) task="${2:-}"; shift 2 ;;
      --summary) summary="${2:-}"; shift 2 ;;
      --files) files="${2:-}"; shift 2 ;;
      --verification) verification="${2:-}"; shift 2 ;;
      --tags) tags="${2:-}"; shift 2 ;;
      --surface) surface="${2:-}"; shift 2 ;;
      *) fail "unknown finish-session argument: $1" ;;
    esac
  done
  [ -n "$task" ] || fail "finish-session requires --task"
  ensure_memory_files
  id="$(active_session_value)"
  if [ -z "$id" ]; then
    id="$(session_id_from_task "$task")"
  fi
  file="$SESSIONS_DIR/$id.env"
  "$0" add-episode --task "$task" --summary "$summary" --files "$files" --verification "$verification" --tags "$tags,$surface"
  {
    printf 'id=%s\n' "$id"
    printf 'task=%s\n' "$task"
    printf 'surface=%s\n' "$surface"
    printf 'finished_at=%s\n' "$(timestamp_utc)"
    printf 'status=finished\n'
  } > "$file"
  rm -f "$ACTIVE_SESSION_FILE"
  printf 'session_id=%s\n' "$id"
  printf 'memory_dir=%s\n' "$MEMORY_DIR"
  printf 'recorded=yes\n'
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
  if [ -n "$pattern" ] && has_command jq; then
    jq -Rr --arg query "$query" '
      def tokens:
        $query
        | ascii_downcase
        | gsub("[^a-z0-9_-]+"; " ")
        | split(" ")
        | map(select(length >= 4))
        | unique
        | .[:8];
      def has_token($text; $token):
        (($text // "") | tostring | ascii_downcase | contains($token));
      def token_score($episode; $token):
        (if has_token(($episode.tags // []) | join(" "); $token) then 8 else 0 end) +
        (if has_token($episode.task; $token) then 5 else 0 end) +
        (if has_token($episode.summary; $token) then 4 else 0 end) +
        (if has_token(($episode.files // []) | join(" "); $token) then 2 else 0 end) +
        (if has_token(($episode.verification // []) | join(" "); $token) then 1 else 0 end);
      (fromjson? // empty) as $episode
      | (tokens) as $tokens
      | (reduce $tokens[] as $token (0; . + token_score($episode; $token))) as $score
      | select($score > 0)
      | [$score, ($episode.created_at // ""), ($episode | tojson)]
      | @tsv
    ' "$EPISODES_FILE" \
      | sort -t "$(printf '\t')" -k1,1nr -k2,2r \
      | head -n 5 \
      | cut -f3-
    return 0
  fi
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
  write_memory_marker "$LAST_CONTEXT_FILE" "context" "$task"
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

print_memory_status() {
  ensure_memory_files
  printf 'memory_dir=%s\n' "$MEMORY_DIR"
  printf 'source=%s\n' "$(memory_source_label)"
  printf 'canonical=%s\n' "$CANONICAL_MEMORY_DIR"
  printf 'old_store_found=%s\n' "$([ -d "$OLD_MEMORY_DIR" ] && printf yes || printf no)"
  printf 'tmp_found=%s\n' "$([ -d "$TMP_MEMORY_DIR" ] && printf yes || printf no)"
  printf 'migrated=%s\n' "$([ "$MEMORY_MIGRATED" -eq 1 ] && printf yes || printf no)"
  printf 'project=%s\n' "$PROJECT_FILE"
  printf 'preferences=%s\n' "$PREFERENCES_FILE"
  printf 'decisions=%s\n' "$DECISIONS_FILE"
  printf 'episodes=%s\n' "$EPISODES_FILE"
  printf 'episode_count=%s\n' "$(wc -l < "$EPISODES_FILE" | tr -d ' ')"
  printf 'last_context_loaded=%s\n' "$([ -f "$LAST_CONTEXT_FILE" ] && sed -n 's/^at=//p' "$LAST_CONTEXT_FILE" | tail -n 1 || printf never)"
  printf 'last_episode_recorded=%s\n' "$([ -f "$LAST_EPISODE_FILE" ] && sed -n 's/^at=//p' "$LAST_EPISODE_FILE" | tail -n 1 || printf never)"
  printf 'active_session=%s\n' "$(active_session_value || true)"
}

memory_doctor() {
  local failures=0
  ensure_memory_files

  printf 'Memory Contract\n'
  printf 'source=%s\n' "$(memory_source_label)"
  printf 'memory_dir=%s\n' "$MEMORY_DIR"
  printf 'canonical=%s\n' "$CANONICAL_MEMORY_DIR"

  if [ "$MEMORY_DIR" != "$CANONICAL_MEMORY_DIR" ] && [ -z "${CODEX_MEMORY_DIR:-}" ]; then
    printf 'FAIL canonical root not selected\n'
    failures=$((failures + 1))
  else
    printf 'OK canonical root selected\n'
  fi

  if [ -w "$MEMORY_DIR" ]; then
    printf 'OK memory root writable\n'
  else
    printf 'FAIL memory root not writable\n'
    failures=$((failures + 1))
  fi

  for file in "$PROJECT_FILE" "$PREFERENCES_FILE" "$DECISIONS_FILE" "$EPISODES_FILE"; do
    if [ -e "$file" ]; then
      printf 'OK %s exists\n' "$(basename "$file")"
    else
      printf 'FAIL %s missing\n' "$file"
      failures=$((failures + 1))
    fi
  done

  for entry in '/.codex/memory/' '/.codex-memory/'; do
    if grep -qxF "$entry" "$ROOT/.gitignore" 2>/dev/null; then
      printf 'OK .gitignore has %s\n' "$entry"
    else
      printf 'FAIL .gitignore missing %s\n' "$entry"
      failures=$((failures + 1))
    fi
  done

  if [ -d "$OLD_MEMORY_DIR" ]; then
    printf 'WARN old memory store exists: %s\n' "$OLD_MEMORY_DIR"
  fi
  if [ -d "$TMP_MEMORY_DIR" ]; then
    printf 'WARN tmp memory exists: %s\n' "$TMP_MEMORY_DIR"
  fi
  if [ -n "$(active_session_value || true)" ]; then
    printf 'WARN active memory session: %s\n' "$(active_session_value)"
  fi

  return "$failures"
}

cleanup_old_stores() {
  local delete="${1:-}"
  ensure_memory_files

  printf 'canonical=%s\n' "$CANONICAL_MEMORY_DIR"
  printf 'old_store=%s\n' "$OLD_MEMORY_DIR"
  printf 'tmp=%s\n' "$TMP_MEMORY_DIR"

  if [ "$delete" != "--delete" ]; then
    printf 'dry_run=yes\n'
    printf 'Pass --delete to remove old stores after migration.\n'
    [ -d "$OLD_MEMORY_DIR" ] && printf 'would_remove=%s\n' "$OLD_MEMORY_DIR"
    [ -d "$TMP_MEMORY_DIR" ] && printf 'would_remove=%s\n' "$TMP_MEMORY_DIR"
    return 0
  fi

  if [ -d "$OLD_MEMORY_DIR" ]; then
    rm -rf "$OLD_MEMORY_DIR"
    printf 'removed=%s\n' "$OLD_MEMORY_DIR"
  fi
  if [ -d "$TMP_MEMORY_DIR" ]; then
    rm -rf "$TMP_MEMORY_DIR"
    printf 'removed=%s\n' "$TMP_MEMORY_DIR"
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
    print_memory_status
    ;;
  doctor)
    memory_doctor
    ;;
  context)
    print_context "$*"
    ;;
  search)
    ensure_memory_files
    [ $# -ge 1 ] || fail "usage: search <query>"
    search_episodes "$*" || true
    ;;
  refresh-project)
    ensure_memory_files
    write_project_memory_file "$*"
    printf '%s\n' "$PROJECT_FILE"
    ;;
  start-session)
    start_memory_session "$@"
    ;;
  finish-session)
    finish_memory_session "$@"
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
    write_memory_marker "$LAST_EPISODE_FILE" "episode" "$task"
    printf '%s\n' "$EPISODES_FILE"
    ;;
  add-decision)
    ensure_memory_files
    [ $# -ge 1 ] || fail "usage: add-decision <text>"
    if grep -F -- "$*" "$DECISIONS_FILE" >/dev/null 2>&1; then
      printf 'duplicate=yes\n'
      printf '%s\n' "$DECISIONS_FILE"
      exit 0
    fi
    printf '\n- %s: %s\n' "$(timestamp_utc)" "$*" >> "$DECISIONS_FILE"
    printf 'duplicate=no\n'
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
  cleanup-old-stores)
    case "${1:-}" in
      ''|--delete) cleanup_old_stores "${1:-}" ;;
      *) fail "usage: cleanup-old-stores [--delete]" ;;
    esac
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
