#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

ROOT="${1:-$(project_root)}"
TASK="${2:-}"
load_repo_intelligence
STACK="$RI_STACK"
CAP_FILE="$(mktemp)"
trap 'rm -f "$CAP_FILE"' EXIT
bash "$(framework_root)/scripts/capabilities.sh" "$ROOT" > "$CAP_FILE"
MEMORY_STATUS="$(cd "$ROOT" && bash "$(framework_root)/scripts/memory-state.sh" status 2>/dev/null || true)"
MEMORY_SOURCE="$(printf '%s\n' "$MEMORY_STATUS" | sed -n 's/^source=//p')"
MEMORY_DIR="$(printf '%s\n' "$MEMORY_STATUS" | sed -n 's/^memory_dir=//p')"
MEMORY_EPISODES="$(printf '%s\n' "$MEMORY_STATUS" | sed -n 's/^episode_count=//p')"
MEMORY_LAST_CONTEXT="$(printf '%s\n' "$MEMORY_STATUS" | sed -n 's/^last_context_loaded=//p')"

printf '⏺ 🧭 Framework Session\n\n'
printf '📁 Project: %s\n' "$ROOT"
printf '🧱 Stack: %s\n' "$STACK"
if [ -n "$TASK" ]; then
  printf '🎯 Task: %s\n' "$TASK"
fi
printf '🧠 Memory: '
if [ -n "$MEMORY_SOURCE" ]; then
  printf '%s (%s episodes' "$MEMORY_SOURCE" "${MEMORY_EPISODES:-0}"
  if [ -n "$MEMORY_LAST_CONTEXT" ] && [ "$MEMORY_LAST_CONTEXT" != "never" ]; then
    printf ', last loaded %s' "$MEMORY_LAST_CONTEXT"
  fi
  printf ')\n'
  printf '   %s\n' "$MEMORY_DIR"
else
  printf 'unavailable\n'
fi

printf '🌐 GitHub: '
if grep -q '^github_structured=yes$' "$CAP_FILE"; then
  printf 'structured tools\n'
elif grep -q '^github_auth_ready=yes$' "$CAP_FILE"; then
  printf 'gh CLI\n'
elif grep -q '^git=yes$' "$CAP_FILE"; then
  printf 'local git only\n'
else
  printf 'unavailable\n'
fi

printf '🧪 Diagnostics: '
if grep -q '^ts_diagnostics=yes$' "$CAP_FILE"; then
  printf 'runtime TS'
elif grep -q '^ts_diagnostics_local=yes$' "$CAP_FILE"; then
  printf 'local TS'
else
  printf 'no TS'
fi
if grep -q '^csharp_diagnostics=yes$' "$CAP_FILE"; then
  printf ' | runtime C#'
elif grep -q '^csharp_diagnostics_local=yes$' "$CAP_FILE"; then
  printf ' | local C#'
fi
printf '\n'

printf '🖥️ Browser: '
if grep -q '^browser_automation=yes$' "$CAP_FILE"; then
  printf 'runtime automation\n'
elif grep -q '^browser_checks_local=yes$' "$CAP_FILE"; then
  printf 'local Playwright\n'
else
  printf 'manual verification only\n'
fi

printf '🪝 Hooks: '
if grep -q '^codex_hooks_configured=yes$' "$CAP_FILE"; then
  printf 'configured\n'
elif grep -q '^codex_hooks_json_valid=yes$' "$CAP_FILE"; then
  printf 'partial\n'
else
  printf 'missing required config\n'
fi

printf '\n'
