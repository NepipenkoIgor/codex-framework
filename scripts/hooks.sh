#!/bin/bash
set -euo pipefail

usage() {
  printf 'usage: hooks.sh <install|doctor|smoke> [project-root]\n'
}

cmd="${1:-}"
[ -n "$cmd" ] || { usage; exit 1; }
shift

FRAMEWORK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_DIR="$(cd "${1:-$PWD}" && pwd)"
TARGET_CONFIG="$TARGET_DIR/.codex/config.toml"

install_hooks() {
  mkdir -p "$(dirname "$TARGET_CONFIG")"
  if [ -e "$TARGET_CONFIG" ]; then
    if grep -Eq '^\[\[hooks\.SessionStart\]\]' "$TARGET_CONFIG" \
      && grep -Eq '^\[\[hooks\.PreToolUse\]\]' "$TARGET_CONFIG" \
      && grep -Eq '^\[\[hooks\.Stop\]\]' "$TARGET_CONFIG" \
      && ! grep -Eq 'PostToolUse|UserPromptSubmit' "$TARGET_CONFIG"; then
      printf 'native hook config already valid: %s\n' "$TARGET_CONFIG"
    return 0
    fi
    printf 'existing config has no compatible native hook contract: %s\n' "$TARGET_CONFIG" >&2
    printf 'refusing to overwrite user configuration; merge the three framework hooks explicitly\n' >&2
    return 1
  fi

  cat > "$TARGET_CONFIG" <<EOF
[agents]
max_threads = 4
max_depth = 1

[[hooks.SessionStart]]
matcher = "startup|resume|clear|.*"

[[hooks.SessionStart.hooks]]
type = "command"
command = "bash '$FRAMEWORK_ROOT/scripts/hooks/session-start.sh'"
timeout = 15
statusMessage = "Loading project context"

[[hooks.PreToolUse]]
matcher = "Bash|Exec|Shell|Terminal"

[[hooks.PreToolUse.hooks]]
type = "command"
command = "bash '$FRAMEWORK_ROOT/scripts/hooks/pre-tool-use.sh'"
timeout = 5
statusMessage = "Checking safety policy"

[[hooks.Stop]]
matcher = ".*"

[[hooks.Stop.hooks]]
type = "command"
command = "bash '$FRAMEWORK_ROOT/scripts/hooks/stop.sh'"
timeout = 30
statusMessage = "Recording verification state"
EOF
  printf '%s\n' "$TARGET_CONFIG"
}

doctor_hooks() {
  local failures=0
  [ -f "$TARGET_CONFIG" ] || { printf 'missing hook config: %s\n' "$TARGET_CONFIG"; return 1; }
  for hook in session-start pre-tool-use stop; do
    [ -f "$FRAMEWORK_ROOT/scripts/hooks/$hook.sh" ] || { printf 'missing hook: %s\n' "$hook"; failures=$((failures + 1)); }
  done
  if grep -q 'PostToolUse\|UserPromptSubmit' "$TARGET_CONFIG"; then
    printf 'drift: unsupported lifecycle hook remains in %s\n' "$TARGET_CONFIG"
    failures=$((failures + 1))
  fi
  [ "$failures" -eq 0 ]
}

smoke_hooks() {
  local sample
  sample='{"tool":"Bash","command":"git status --short"}'
  printf '%s\n' "$sample" | bash "$FRAMEWORK_ROOT/scripts/hooks/pre-tool-use.sh" >/dev/null
  sample='{"tool":"Bash","command":"git checkout -b codex/hook-smoke"}'
  if printf '%s\n' "$sample" | bash "$FRAMEWORK_ROOT/scripts/hooks/pre-tool-use.sh" >/dev/null 2>&1; then
    printf 'pre-tool-use did not block codex/* branch creation\n'
    return 1
  fi
  printf 'hook smoke passed\n'
}

case "$cmd" in
  install) install_hooks ;;
  doctor) doctor_hooks ;;
  smoke) smoke_hooks ;;
  *) usage; exit 1 ;;
esac
