#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

usage() {
  cat <<EOF
usage: context-pack.sh [--task "<task text>"] [--mode <desktop|session|hook>]
EOF
}

TASK=""
MODE="session"

while [ $# -gt 0 ]; do
  case "$1" in
    --task)
      TASK="${2:-}"
      shift 2
      ;;
    --mode)
      MODE="${2:-session}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

ROOT="$(project_root)"
FRAMEWORK_ROOT="$(framework_root)"

if [ "${CODEX_CONTEXT_PACK_SKIP_BOOTSTRAP:-0}" != "1" ]; then
  ensure_project_bootstrap "$ROOT"
fi

load_repo_intelligence

memory_status="$(bash "$FRAMEWORK_ROOT/scripts/memory-state.sh" status 2>/dev/null || true)"
memory_context="$(bash "$FRAMEWORK_ROOT/scripts/memory-state.sh" context "$TASK" 2>/dev/null || echo "none")"
capabilities="$(bash "$FRAMEWORK_ROOT/scripts/capabilities.sh" "$ROOT" 2>/dev/null || true)"
banner="$(bash "$FRAMEWORK_ROOT/scripts/banner.sh" "$ROOT" "$TASK" 2>/dev/null || true)"
agent_registry_status="$(bash "$FRAMEWORK_ROOT/scripts/agent-registry.sh" validate 2>/dev/null || echo "agent registry validation failed")"
agent_count="$(bash "$FRAMEWORK_ROOT/scripts/agent-registry.sh" list 2>/dev/null | awk 'NR > 1 { count++ } END { print count + 0 }')"

cat <<EOF
## Codex Framework Context Pack

- Project root: $ROOT
- Framework root: $FRAMEWORK_ROOT
- Mode: $MODE
- Task: ${TASK:-not provided}

## Startup Banner

\`\`\`text
$banner
\`\`\`

## Repo Intelligence

\`\`\`text
$(repo_intelligence_summary)
\`\`\`

## Capabilities

\`\`\`text
$capabilities
\`\`\`

## Memory

Status:

\`\`\`text
$memory_status
\`\`\`

\`\`\`text
$memory_context
\`\`\`

## Named Agents

- Registry: $FRAMEWORK_ROOT/agents/registry.tsv
- Count: $agent_count
- Validation: $agent_registry_status
- Prompt builder: \`codex-fw agent prompt <agent> --task "<task>" --skills "<csv>" --ownership "<scope>"\`

## Operating Contract

- Treat this context as a startup hint, not as proof.
- Verify important facts against the repository before changing code.
- Use generated briefs for non-trivial work when available.
- Keep unrelated user changes intact.
- Run targeted verification and guard checks before close-out.
EOF
