#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

payload_file="$(hook_read_payload)"
task="$(hook_task_from_payload "$payload_file")"
root="$(hook_project_root)"

cd "$root"
hook_record_event "SessionStart" "$task"

bash "$FRAMEWORK_ROOT/scripts/context-pack.sh" --task "${task:-session start}" --mode hook
