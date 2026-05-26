#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

payload_file="$(hook_read_payload)"
root="$(hook_project_root)"
task="$(hook_current_task)"

cd "$root"
hook_record_event "Stop" "${task:-session stop}"

changed="$(git_changed_files 2>/dev/null || true)"
if [ -z "$changed" ]; then
  exit 0
fi

checks_file="$(hook_state_dir)/stop-checks.txt"
{
  printf 'Codex Framework Stop hook\n'
  printf 'changed files:\n%s\n\n' "$changed"
  printf 'guard scan:\n'
  bash "$FRAMEWORK_ROOT/scripts/guard-scan.sh" --changed
  printf '\nquality check:\n'
  bash "$FRAMEWORK_ROOT/scripts/quality-check.sh" --changed
} > "$checks_file" 2>&1 || {
  printf 'Codex Framework Stop hook recorded required check failures: %s\n' "$checks_file" >&2
  if [ "$(hook_enforce_mode)" = "block" ]; then
    exit 2
  fi
}

record_memory_episode "${task:-Codex hook session}" "Stop hook observed changed files and recorded required verification state." "hook,desktop" || true

exit 0
