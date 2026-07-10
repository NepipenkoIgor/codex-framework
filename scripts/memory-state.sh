#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

usage() {
  cat <<EOF
usage: memory-state.sh <init|repair|status|doctor|context|search|retro|refresh-project|start-session|finish-session|add-episode|add-note|add-decision|compact|prune|get> ...

commands:
  init
  repair
  status
  doctor
  context [task text]
  search <query>
  retro
  refresh-project [task text]
  start-session --task <text> [--surface <cli|desktop>]
  finish-session --task <text> [--summary <text>] [--files <csv>] [--verification <csv>] [--tags <csv>] [--surface <cli|desktop>] [--role <name>] [--notes-codebase <text>] [--notes-memory <text>] [--notes-backlog <text>]
  add-episode --task <text> [--summary <text>] [--files <csv>] [--verification <csv>] [--tags <csv>]
  add-note --type <codebase|memory|backlog|standup> --text <text> [--role <name>]
  add-decision <text>
  compact [keep-count]
  prune [keep-count]
  get
EOF
}

ROOT="$(project_root)"
FRAMEWORK_ROOT="$(framework_root)"
CANONICAL_MEMORY_DIR="$ROOT/.codex-memory"

select_memory_root_readonly() {
  if [ -n "${CODEX_MEMORY_DIR:-}" ]; then
    printf '%s\n' "$CODEX_MEMORY_DIR"
  else
    printf '%s\n' "$CANONICAL_MEMORY_DIR"
  fi
}

set_memory_paths() {
  MEMORY_DIR="$1"
  PROJECT_FILE="$MEMORY_DIR/project.md"
  PREFERENCES_FILE="$MEMORY_DIR/preferences.md"
  DECISIONS_FILE="$MEMORY_DIR/decisions.local.md"
  CODEBASE_NOTES_FILE="$MEMORY_DIR/CODEBASE_NOTES.md"
  EPISODES_FILE="$MEMORY_DIR/episodes.jsonl"
  SUMMARIES_DIR="$MEMORY_DIR/summaries"
  SESSIONS_DIR="$MEMORY_DIR/sessions"
  ROLES_DIR="$MEMORY_DIR/roles"
  STUDIO_DIR="$MEMORY_DIR/_studio"
  STANDUP_FILE="$STUDIO_DIR/STANDUP.md"
  LAST_EPISODE_FILE="$MEMORY_DIR/.last-episode-recorded"
  ACTIVE_SESSION_FILE="$MEMORY_DIR/.active-session"
}

set_memory_paths "$(select_memory_root_readonly)"

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
  printf '%s\n' "$entry" >> "$gitignore"
}

ensure_memory_gitignore() {
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
  local stable_notes
  stable_notes="$(stable_notes_block)"
  cat > "$PROJECT_FILE" <<EOF
# Project Memory

Durable local project facts for native Codex sessions.

- Root: $ROOT
- Refreshed at: $(timestamp_utc)

$stable_notes
EOF
}

memory_source_label() {
  if [ -n "${CODEX_MEMORY_DIR:-}" ] && [ "$MEMORY_DIR" = "$CODEX_MEMORY_DIR" ]; then
    printf 'override\n'
  elif [ "$MEMORY_DIR" = "$CANONICAL_MEMORY_DIR" ]; then
    printf 'canonical\n'
  else
    printf 'custom\n'
  fi
}

ensure_memory_files() {
  set_memory_paths "$(memory_root)"
  ensure_memory_gitignore
  mkdir -p "$MEMORY_DIR" "$SUMMARIES_DIR" "$SESSIONS_DIR" "$ROLES_DIR" "$STUDIO_DIR"
  touch "$EPISODES_FILE"

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

  if [ ! -f "$CODEBASE_NOTES_FILE" ]; then
    cat > "$CODEBASE_NOTES_FILE" <<EOF
# Codebase Notes

Running log of non-obvious framework discoveries and durable lessons.
EOF
  fi

  if [ ! -f "$STANDUP_FILE" ]; then
    cat > "$STANDUP_FILE" <<EOF
# Standup

Newest entries last. Keep this compact so SessionStart can surface continuity cheaply.
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
  printf 'session_id=%s\n' "$id"
  printf 'memory_dir=%s\n' "$MEMORY_DIR"
  printf 'source=%s\n' "$(memory_source_label)"
}

finish_memory_session() {
  local task="" summary="" files="" verification="" tags="session" surface="desktop" role="session" notes_codebase="" notes_memory="" notes_backlog="" id file
  while [ $# -gt 0 ]; do
    case "$1" in
      --task) task="${2:-}"; shift 2 ;;
      --summary) summary="${2:-}"; shift 2 ;;
      --files) files="${2:-}"; shift 2 ;;
      --verification) verification="${2:-}"; shift 2 ;;
      --tags) tags="${2:-}"; shift 2 ;;
      --surface) surface="${2:-}"; shift 2 ;;
      --role) role="${2:-session}"; shift 2 ;;
      --notes-codebase) notes_codebase="${2:-}"; shift 2 ;;
      --notes-memory) notes_memory="${2:-}"; shift 2 ;;
      --notes-backlog) notes_backlog="${2:-}"; shift 2 ;;
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
  [ -n "$notes_codebase" ] && append_memory_note --type codebase --role "$role" --text "$notes_codebase" >/dev/null
  [ -n "$notes_memory" ] && append_memory_note --type memory --role "$role" --text "$notes_memory" >/dev/null
  [ -n "$notes_backlog" ] && append_memory_note --type backlog --role "$role" --text "$notes_backlog" >/dev/null
  append_memory_note --type standup --role "$role" --text "done: $task | status: finished | next: none" >/dev/null
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

search_text_file() {
  local title="$1"
  local file="$2"
  local pattern="$3"
  local matches
  [ -s "$file" ] || return 0
  if [ -n "$pattern" ]; then
    if has_command rg; then
      matches="$(rg -i "$pattern" "$file" | tail -n 5 || true)"
    else
      matches="$(grep -Ei "$pattern" "$file" | tail -n 5 || true)"
    fi
  else
    matches="$(tail -n 5 "$file")"
  fi
  [ -n "$matches" ] || return 0
  printf '## %s\n%s\n' "$title" "$matches"
}

search_memory() {
  local query="$1"
  local pattern
  local matches inbox
  pattern="$(query_pattern "$query")"
  printf '## Episodes\n'
  matches="$(search_episodes "$query")"
  if [ -n "$matches" ]; then
    printf '%s\n' "$matches"
  else
    printf 'none\n'
  fi
  search_text_file "Codebase Notes" "$CODEBASE_NOTES_FILE" "$pattern"
  if [ -d "$ROLES_DIR" ]; then
    while IFS= read -r inbox; do
      search_text_file "Role Inbox ${inbox#$ROLES_DIR/}" "$inbox" "$pattern"
    done < <(find "$ROLES_DIR" -path '*/INBOX.md' -type f 2>/dev/null | sort)
  fi
  search_text_file "Studio Standup" "$STANDUP_FILE" "$pattern"
}

memory_retro_report() {
  local inbox_count=0
  local inbox_lines=0
  local note_lines
  local standup_lines
  local inbox
  note_lines="$(file_line_count "$CODEBASE_NOTES_FILE")"
  standup_lines="$(file_line_count "$STANDUP_FILE")"
  if [ -d "$ROLES_DIR" ]; then
    while IFS= read -r inbox; do
      inbox_count=$((inbox_count + 1))
      inbox_lines=$((inbox_lines + $(file_line_count "$inbox")))
    done < <(find "$ROLES_DIR" -path '*/INBOX.md' -type f 2>/dev/null | sort)
  fi

  printf 'Memory Retro\n'
  printf 'memory_dir=%s\n' "$MEMORY_DIR"
  printf 'codebase_note_lines=%s\n' "$note_lines"
  printf 'role_inboxes=%s\n' "$inbox_count"
  printf 'role_inbox_lines=%s\n' "$inbox_lines"
  printf 'standup_lines=%s\n' "$standup_lines"
  printf '\n## Recommended Curation\n'
  if [ "$note_lines" -gt 40 ] || [ "$inbox_lines" -gt 20 ]; then
    printf '%s\n' '- required: prune or promote memory before more task sessions.'
  elif [ "$note_lines" -gt 20 ] || [ "$inbox_lines" -gt 10 ]; then
    printf '%s\n' '- recommended: review memory soon and promote durable rules.'
  else
    printf '%s\n' '- none: memory volume is still compact.'
  fi
  printf '%s\n' '- promote stable project facts to project.md Stable Notes.'
  printf '%s\n' '- promote workflow decisions to decisions.local.md or tracked ADRs.'
  printf '%s\n' '- promote reusable behavior to AGENTS.md, skills, or framework checks.'
  printf '\n## Recent Codebase Notes\n'
  if [ -s "$CODEBASE_NOTES_FILE" ]; then
    tail -n 10 "$CODEBASE_NOTES_FILE"
  else
    printf 'none\n'
  fi
  printf '\n## Role Inboxes\n'
  if [ -d "$ROLES_DIR" ]; then
    find "$ROLES_DIR" -path '*/INBOX.md' -type f 2>/dev/null | sort | while IFS= read -r inbox; do
      printf '### %s\n' "${inbox#$ROLES_DIR/}"
      tail -n 5 "$inbox"
    done
  else
    printf 'none\n'
  fi
}

print_context() {
  local task="${1:-}"
  print_limited_file "Project Memory" "$PROJECT_FILE" 80
  print_limited_file "Operator Preferences" "$PREFERENCES_FILE" 40
  print_limited_file "Local Decisions" "$DECISIONS_FILE" 60
  print_limited_file "Codebase Notes" "$CODEBASE_NOTES_FILE" 80
  print_limited_file "Studio Standup" "$STANDUP_FILE" 20
  printf '## Relevant Episodes\n'
  matches="$(search_episodes "$task")"
  if [ -n "$matches" ]; then
    printf '%s\n' "$matches"
  else
    printf 'none\n'
  fi
}

file_line_count() {
  local file="$1"
  if [ -f "$file" ]; then
    wc -l < "$file" | tr -d ' '
  else
    printf '0\n'
  fi
}

memory_initialized() {
  [ -d "$MEMORY_DIR" ] \
    && [ -f "$PROJECT_FILE" ] \
    && [ -f "$PREFERENCES_FILE" ] \
    && [ -f "$DECISIONS_FILE" ] \
    && [ -f "$CODEBASE_NOTES_FILE" ] \
    && [ -f "$EPISODES_FILE" ] \
    && [ -f "$STANDUP_FILE" ]
}

print_memory_status() {
  printf 'memory_dir=%s\n' "$MEMORY_DIR"
  printf 'source=%s\n' "$(memory_source_label)"
  printf 'canonical=%s\n' "$CANONICAL_MEMORY_DIR"
  printf 'initialized=%s\n' "$(memory_initialized && printf yes || printf no)"
  printf 'project=%s\n' "$PROJECT_FILE"
  printf 'preferences=%s\n' "$PREFERENCES_FILE"
  printf 'decisions=%s\n' "$DECISIONS_FILE"
  printf 'codebase_notes=%s\n' "$CODEBASE_NOTES_FILE"
  printf 'episodes=%s\n' "$EPISODES_FILE"
  printf 'episode_count=%s\n' "$(file_line_count "$EPISODES_FILE")"
  printf 'codebase_note_lines=%s\n' "$(file_line_count "$CODEBASE_NOTES_FILE")"
  printf 'last_episode_recorded=%s\n' "$([ -f "$LAST_EPISODE_FILE" ] && sed -n 's/^at=//p' "$LAST_EPISODE_FILE" | tail -n 1 || printf never)"
  printf 'active_session=%s\n' "$(active_session_value || true)"
}

memory_doctor() {
  local failures=0

  printf 'Memory Contract\n'
  printf 'source=%s\n' "$(memory_source_label)"
  printf 'memory_dir=%s\n' "$MEMORY_DIR"
  printf 'canonical=%s\n' "$CANONICAL_MEMORY_DIR"
  printf 'read_only=yes\n'

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

  for file in "$PROJECT_FILE" "$PREFERENCES_FILE" "$DECISIONS_FILE" "$CODEBASE_NOTES_FILE" "$EPISODES_FILE" "$STANDUP_FILE"; do
    if [ -e "$file" ]; then
      printf 'OK %s exists\n' "$(basename "$file")"
    else
      printf 'FAIL %s missing\n' "$file"
      failures=$((failures + 1))
    fi
  done

  for entry in '/.codex-memory/'; do
    if grep -qxF "$entry" "$ROOT/.gitignore" 2>/dev/null; then
      printf 'OK .gitignore has %s\n' "$entry"
    else
      printf 'FAIL .gitignore missing %s\n' "$entry"
      failures=$((failures + 1))
    fi
  done

  if [ -n "$(active_session_value || true)" ]; then
    printf 'WARN active memory session: %s\n' "$(active_session_value)"
  fi

  return "$failures"
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

sanitize_role_name() {
  printf '%s' "${1:-session}" \
    | tr '[:upper:]' '[:lower:]' \
    | tr -cs '[:alnum:]_-' '-' \
    | sed 's/^-//; s/-$//'
}

append_memory_note() {
  local type="" text="" role="session" role_dir inbox tmp
  while [ $# -gt 0 ]; do
    case "$1" in
      --type) type="${2:-}"; shift 2 ;;
      --text) text="${2:-}"; shift 2 ;;
      --role) role="${2:-session}"; shift 2 ;;
      *) fail "unknown add-note argument: $1" ;;
    esac
  done
  [ -n "$type" ] || fail "add-note requires --type"
  [ -n "$text" ] || fail "add-note requires --text"
  ensure_memory_files

  role="$(sanitize_role_name "$role")"
  [ -n "$role" ] || role="session"

  case "$type" in
    codebase)
      printf '\n- %s [%s] %s\n' "$(timestamp_utc)" "$role" "$text" >> "$CODEBASE_NOTES_FILE"
      printf '%s\n' "$CODEBASE_NOTES_FILE"
      ;;
    backlog)
      printf '\n- %s [backlog] [%s] %s\n' "$(timestamp_utc)" "$role" "$text" >> "$CODEBASE_NOTES_FILE"
      printf '%s\n' "$CODEBASE_NOTES_FILE"
      ;;
    memory)
      role_dir="$ROLES_DIR/$role"
      mkdir -p "$role_dir"
      inbox="$role_dir/INBOX.md"
      [ -f "$inbox" ] || printf '# Inbox\n\n' > "$inbox"
      printf '%s\n' "- $(timestamp_utc) feedback: $text" >> "$inbox"
      printf '%s\n' "$inbox"
      ;;
    standup)
      [ -f "$STANDUP_FILE" ] || printf '# Standup\n\n' > "$STANDUP_FILE"
      printf '%s\n' "- $(timestamp_utc) $text" >> "$STANDUP_FILE"
      tmp="$STANDUP_FILE.tmp.$$"
      {
        sed -n '1,3p' "$STANDUP_FILE"
        grep '^- ' "$STANDUP_FILE" | tail -n 5
      } > "$tmp" && mv "$tmp" "$STANDUP_FILE"
      printf '%s\n' "$STANDUP_FILE"
      ;;
    *)
      fail "unknown note type: $type"
      ;;
  esac
}

cmd="${1:-}"
shift || true

case "$cmd" in
  init)
    ensure_memory_files
    printf '%s\n' "$MEMORY_DIR"
    ;;
  repair)
    ensure_memory_files
    printf 'repaired=%s\n' "$MEMORY_DIR"
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
    [ $# -ge 1 ] || fail "usage: search <query>"
    search_memory "$*" || true
    ;;
  retro)
    memory_retro_report
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
  add-note)
    append_memory_note "$@"
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
  get)
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
