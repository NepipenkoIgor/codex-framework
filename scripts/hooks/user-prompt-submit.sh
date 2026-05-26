#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

payload_file="$(hook_read_payload)"
prompt="$(hook_task_from_payload "$payload_file")"
root="$(hook_project_root)"

[ -n "$prompt" ] || exit 0

cd "$root"
hook_save_current_task "$prompt"
hook_record_event "UserPromptSubmit" "$prompt"

decision="$(bash "$FRAMEWORK_ROOT/scripts/codex-fw.sh" route "$prompt" 2>/dev/null || true)"
[ -n "$decision" ] || exit 0

role="$(printf '%s\n' "$decision" | sed -n 's/.*role=\([^ ]*\).*/\1/p')"
skills="$(printf '%s\n' "$decision" | sed -n 's/.*skills=\([^ ]*\).*/\1/p')"
tier="$(printf '%s\n' "$decision" | sed -n 's/.*tier=\([^ ]*\).*/\1/p')"
model="$(printf '%s\n' "$decision" | sed -n 's/.*model=\([^ ]*\).*/\1/p')"
agent_runtime="$(bash "$FRAMEWORK_ROOT/scripts/agent-registry.sh" get "${role:-builder}" runtime_type 2>/dev/null || printf 'default\n')"
agent_work_mode="$(bash "$FRAMEWORK_ROOT/scripts/agent-registry.sh" get "${role:-builder}" work_mode 2>/dev/null || printf 'unknown\n')"

cat <<EOF
## Codex Framework Intake

- Route badge: $(route_badge "${role:-builder}" "${model:-$(codex_medium_model)}" "${tier:-medium}")
- Owner: ${role:-unknown}
- Named agent: ${role:-unknown} (${agent_runtime}, ${agent_work_mode})
- Tier: ${tier:-unknown}
- Model: ${model:-unknown}
- Skills: ${skills:-none}

Use this as routing guidance. Load skill bodies lazily only when needed. Spawn sub-agents only for bounded parallel work, using the named agent registry for runtime type and prompt.
EOF
