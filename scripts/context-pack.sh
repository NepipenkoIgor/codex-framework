#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

TASK="${1:-session start}"
ROOT="$(project_root)"
FRAMEWORK_ROOT="$(framework_root)"
memory_status="$(bash "$FRAMEWORK_ROOT/scripts/memory-state.sh" status)"
memory_context="$(bash "$FRAMEWORK_ROOT/scripts/memory-state.sh" context "$TASK")"

cat <<EOF
## Codex Framework Context

- Project root: $ROOT
- Framework root: $FRAMEWORK_ROOT
- Task: $TASK

## Durable Project Memory

```text
$memory_status
```

```text
$memory_context
```

## Native Contract

- Read AGENTS.md and repository-local instructions before editing.
- Use native planning, skills, custom agents, worktrees, approvals, plugins, and MCP.
- Verify the actual diff and changed behavior before closeout.
EOF
