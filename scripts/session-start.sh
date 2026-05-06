#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

ROOT="$(project_root)"
FRAMEWORK_ROOT="$(framework_root)"
TASK=""
SESSION_ROOT="$ROOT"
TASK_WORKTREE_ENABLED="${CODEX_TASK_WORKTREE:-1}"

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

case "$TASK_WORKTREE_ENABLED" in
  1|true|TRUE|yes|YES)
    TASK_WORKTREE_ENABLED="yes"
    ;;
  *)
    TASK_WORKTREE_ENABLED="no"
    ;;
esac

if [ -n "$TASK" ] && [ "$TASK_WORKTREE_ENABLED" = "yes" ] && git rev-parse --show-toplevel >/dev/null 2>&1; then
  SESSION_ROOT="$(ensure_task_worktree "$ROOT" "$TASK")"
fi

cd "$SESSION_ROOT"
ensure_project_bootstrap "$SESSION_ROOT"
print_section "Session Progress"
info "stage: refresh repo intelligence"
run_with_spinner "refresh repo intelligence" load_repo_intelligence >/dev/null
load_repo_intelligence
ensure_run_root
info "stage: collect preflight, capabilities, and banner"

preflight_file="$(run_root)/$(date -u +"%Y%m%dT%H%M%SZ")-preflight.txt"
capabilities_file="$(run_root)/$(date -u +"%Y%m%dT%H%M%SZ")-capabilities.txt"
memory_file="$(run_root)/$(date -u +"%Y%m%dT%H%M%SZ")-memory.md"
session_file="$(run_root)/$(date -u +"%Y%m%dT%H%M%SZ")-session.md"
banner_file="$(run_root)/$(date -u +"%Y%m%dT%H%M%SZ")-banner.txt"
brief_file=""
plan_file=""
wait_for_go="no"

bash "$FRAMEWORK_ROOT/scripts/preflight.sh" > "$preflight_file"
bash "$FRAMEWORK_ROOT/scripts/capabilities.sh" "$SESSION_ROOT" > "$capabilities_file"
bash "$FRAMEWORK_ROOT/scripts/banner.sh" "$SESSION_ROOT" "$TASK" > "$banner_file"
bash "$FRAMEWORK_ROOT/scripts/memory-state.sh" context "$TASK" > "$memory_file"

if [ -n "$TASK" ]; then
  info "stage: generate task brief and plan"
  brief_file="$(
    CODEX_SKIP_BOOTSTRAP=1 CODEX_SKIP_REPO_REFRESH=1 run_with_spinner "generate task brief" bash "$FRAMEWORK_ROOT/scripts/task-brief.sh" --task "$TASK"
  )"
  plan_file="$(
    CODEX_SKIP_BOOTSTRAP=1 CODEX_SKIP_REPO_REFRESH=1 run_with_spinner "generate session plan" bash "$FRAMEWORK_ROOT/scripts/plan.sh" --task "$TASK" --brief "$brief_file"
  )"
  route_role="$(sed -n 's/^- Chosen owner: //p; s/^- Role: //p' "$brief_file")"
  route_reasoning="$(sed -n 's/^- Reasoning depth: //p; s/^- Reasoning: //p' "$brief_file")"
  route_flags="$(sed -n 's/^- Task flags: //p' "$brief_file")"
  route_shape="$(sed -n 's/^- Task shape: //p' "$brief_file")"
  if codex_should_wait_for_go "$route_role" "$route_reasoning" "$route_shape" "$route_flags" "$TASK"; then
    wait_for_go="yes"
  fi
fi

cat > "$session_file" <<EOF
# Codex Framework Session Context

Project root: $SESSION_ROOT

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

## Memory Context

\`\`\`text
$(cat "$memory_file")
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
  if [ "$wait_for_go" = "yes" ]; then
    cat >> "$session_file" <<EOF

## Session Plan

Print this plan file verbatim first, preserving emoji, bullets, spacing, and wording. Do not summarize, paraphrase, or reformat it. Then wait for explicit \`go\` before execution:

- $plan_file
EOF
  else
    cat >> "$session_file" <<EOF

## Session Plan

Print this plan file verbatim first, preserving emoji, bullets, spacing, and wording. Do not summarize, paraphrase, or reformat it. Then proceed without waiting for an extra approval:

- $plan_file
EOF
  fi
fi

cat >> "$session_file" <<EOF

## Session Display Contract

- Start by showing the startup banner.
- If there is a task plan, print the plan file verbatim before any execution.
- Wait for explicit \`go\` when the route is high-risk, contract-bearing, strategic, or when \`CODEX_WAIT_FOR_GO=1\`.
- Proceed after the plan for low-risk mechanical work, or when \`CODEX_WAIT_FOR_GO=0\`.
- During work, use short status blocks with a compact route badge such as `fix-5.5-h` and decorated skills.
- Keep updates concise but make the active owner visible.
- End task work with the canonical Output Contract from the task brief. Keep section names and ordering exactly. Do not use legacy `Status:` / `Requirement:` label-format closeouts.
EOF

prompt="Read $session_file first. Use the framework for this project."
if [ -n "$brief_file" ]; then
  if [ "$wait_for_go" = "yes" ]; then
    prompt="$prompt Show the startup banner first. Then print $plan_file verbatim, preserving emoji, bullets, spacing, and wording. Wait for explicit 'go' before executing the task from $brief_file. Use the session display contract for progress updates and the task brief Output Contract for final closeout. Do not use legacy Status:/Requirement: closeout labels."
  else
    prompt="$prompt Show the startup banner first. Then print $plan_file verbatim, preserving emoji, bullets, spacing, and wording. Proceed directly into executing the task from $brief_file. Use the session display contract for progress updates and the task brief Output Contract for final closeout. Do not use legacy Status:/Requirement: closeout labels."
  fi
else
  prompt="$prompt Show the startup banner first and use the session display contract for progress updates."
fi

info "stage: launch Codex session"
cd "$SESSION_ROOT"
if ! codex_run "$prompt"; then
  fail "Codex session failed"
fi

if [ -n "$TASK" ]; then
  record_memory_episode "$TASK" "Task session completed through session-start." "task-session"
fi
