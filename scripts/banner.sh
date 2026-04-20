#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

ROOT="${1:-$(project_root)}"
TASK="${2:-}"
STACK="$(bash "$(framework_root)/scripts/detect-project-stack.sh" "$ROOT" 2>/dev/null || echo unknown)"
CAP_FILE="$(mktemp)"
trap 'rm -f "$CAP_FILE"' EXIT
bash "$(framework_root)/scripts/capabilities.sh" "$ROOT" > "$CAP_FILE"

printf '⏺ 🧭 Framework Session\n\n'
printf '📁 Project: %s\n' "$ROOT"
printf '🧱 Stack: %s\n' "$STACK"
if [ -n "$TASK" ]; then
  printf '🎯 Task: %s\n' "$TASK"
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
  printf 'local TS fallback'
else
  printf 'no TS'
fi
if grep -q '^csharp_diagnostics=yes$' "$CAP_FILE"; then
  printf ' | runtime C#'
elif grep -q '^csharp_diagnostics_local=yes$' "$CAP_FILE"; then
  printf ' | local C# fallback'
fi
printf '\n'

printf '🖥️ Browser: '
if grep -q '^browser_automation=yes$' "$CAP_FILE"; then
  printf 'runtime automation\n'
elif grep -q '^browser_checks_local=yes$' "$CAP_FILE"; then
  printf 'local Playwright fallback\n'
else
  printf 'manual verification only\n'
fi

printf '\n'
