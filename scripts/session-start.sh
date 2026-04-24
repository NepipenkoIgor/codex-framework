#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

ROOT="$(project_root)"
FRAMEWORK_ROOT="$(framework_root)"
TASK=""

while [ $# -gt 0 ]; do
  case "$1" in
    --task|-t)
      TASK="${2:-}"
      shift 2
      ;;
    *)
      fail "usage: session-start.sh [--task \"task text\"]"
      ;;
  esac
done

ensure_project_bootstrap "$ROOT"
refresh_repo_intelligence >/dev/null
load_repo_intelligence
ensure_run_root

preflight_file="$(run_root)/$(date -u +"%Y%m%dT%H%M%SZ")-preflight.txt"
capabilities_file="$(run_root)/$(date -u +"%Y%m%dT%H%M%SZ")-capabilities.txt"
session_file="$(run_root)/$(date -u +"%Y%m%dT%H%M%SZ")-session.md"
banner_file="$(run_root)/$(date -u +"%Y%m%dT%H%M%SZ")-banner.txt"
brief_file=""
plan_file=""

bash "$FRAMEWORK_ROOT/scripts/preflight.sh" > "$preflight_file"
bash "$FRAMEWORK_ROOT/scripts/capabilities.sh" "$ROOT" > "$capabilities_file"
bash "$FRAMEWORK_ROOT/scripts/banner.sh" "$ROOT" "$TASK" > "$banner_file"

if [ -n "$TASK" ]; then
  brief_file="$(bash "$FRAMEWORK_ROOT/scripts/task-brief.sh" --task "$TASK")"
  plan_file="$(bash "$FRAMEWORK_ROOT/scripts/plan.sh" --task "$TASK")"
fi

cat > "$session_file" <<EOF
# Codex Framework Session Context

Project root: $ROOT

## Required Reads

- $ROOT/CODEX.md
- $FRAMEWORK_ROOT/CODEX.md
- $FRAMEWORK_ROOT/CODEX.concepts.md
- $FRAMEWORK_ROOT/CODEX.skills.md
- $FRAMEWORK_ROOT/CODEX.capabilities.md
- $FRAMEWORK_ROOT/CODEX.permissions.md
- $FRAMEWORK_ROOT/ORCHESTRATOR_REFERENCE.md
- $(cached_repo_intelligence_file)

## Startup Banner

\`\`\`text
$(cat "$banner_file")
\`\`\`

## Preflight

\`\`\`text
$(cat "$preflight_file")
\`\`\`

## Capabilities

\`\`\`text
$(cat "$capabilities_file")
\`\`\`

## Repo Intelligence

\`\`\`text
$(repo_intelligence_summary)
\`\`\`
EOF

if [ -n "$brief_file" ]; then
  cat >> "$session_file" <<EOF

## Task Brief

Read:

- $brief_file
EOF
fi

if [ -n "$plan_file" ]; then
  cat >> "$session_file" <<EOF

## Session Plan

Show this plan first and wait for explicit \`go\` before execution:

- $plan_file
EOF
fi

cat >> "$session_file" <<EOF

## Session Display Contract

- Start by showing the startup banner.
- If there is a task plan, show it before any execution.
- Wait for explicit \`go\` before starting planned work.
- During work, use short status blocks that show role, model, tier, and decorated skills.
- Keep updates concise but make the active owner visible.
EOF

prompt="Read $session_file first. Use the framework for this project."
if [ -n "$brief_file" ]; then
  prompt="$prompt Show the startup banner first. Then read $plan_file and show that plan first. Wait for explicit 'go' before executing the task from $brief_file. Use the session display contract for progress updates."
else
  prompt="$prompt Show the startup banner first and use the session display contract for progress updates."
fi

cd "$ROOT"
codex_exec "$prompt"
