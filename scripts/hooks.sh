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
TARGET_HOOKS_DIR="$TARGET_DIR/.codex/hooks"

install_hooks() {
  mkdir -p "$(dirname "$TARGET_CONFIG")"
  if [ -e "$TARGET_CONFIG" ]; then
    if grep -Eq '^\[\[hooks\.PreToolUse\]\]' "$TARGET_CONFIG" \
      && grep -Eq '^\[\[hooks\.Stop\]\]' "$TARGET_CONFIG" \
      && ! grep -Eq 'SessionStart|PostToolUse|UserPromptSubmit' "$TARGET_CONFIG"; then
      printf 'native hook config already valid: %s\n' "$TARGET_CONFIG"
    return 0
    fi
    printf 'existing config has no compatible native hook contract: %s\n' "$TARGET_CONFIG" >&2
    printf 'refusing to overwrite user configuration; merge the two framework hooks explicitly\n' >&2
    return 1
  fi

  mkdir -p "$TARGET_HOOKS_DIR"
  cp "$FRAMEWORK_ROOT/scripts/hooks/pre-tool-use.sh" "$TARGET_HOOKS_DIR/pre-tool-use.sh"
  cp "$FRAMEWORK_ROOT/scripts/hooks/stop.sh" "$TARGET_HOOKS_DIR/stop.sh"

  cat > "$TARGET_CONFIG" <<EOF
[agents]
max_concurrent_threads_per_session = 4
max_depth = 1

[[hooks.PreToolUse]]
matcher = "Bash|Exec|Shell|Terminal"

[[hooks.PreToolUse.hooks]]
type = "command"
command = 'bash "\$(git rev-parse --show-toplevel)/.codex/hooks/pre-tool-use.sh"'
timeout = 5
statusMessage = "Checking safety policy"

[[hooks.Stop]]
matcher = ".*"

[[hooks.Stop.hooks]]
type = "command"
command = 'bash "\$(git rev-parse --show-toplevel)/.codex/hooks/stop.sh"'
timeout = 30
statusMessage = "Checking changed files"
EOF
  printf '%s\n' "$TARGET_CONFIG"
}

doctor_hooks() {
  local failures=0 hook_dir="$TARGET_HOOKS_DIR"
  [ -f "$TARGET_CONFIG" ] || { printf 'missing hook config: %s\n' "$TARGET_CONFIG"; return 1; }
  [ "$TARGET_DIR" = "$FRAMEWORK_ROOT" ] && hook_dir="$FRAMEWORK_ROOT/scripts/hooks"
  for hook in pre-tool-use stop; do
    [ -f "$hook_dir/$hook.sh" ] || { printf 'missing hook: %s\n' "$hook"; failures=$((failures + 1)); }
  done
  if grep -q 'SessionStart\|PostToolUse\|UserPromptSubmit' "$TARGET_CONFIG"; then
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
  printf '%s\n' "$sample" | bash "$FRAMEWORK_ROOT/scripts/hooks/pre-tool-use.sh" >/dev/null
  sample='{"tool":"Bash","command":"git reset --hard HEAD"}'
  if printf '%s\n' "$sample" | bash "$FRAMEWORK_ROOT/scripts/hooks/pre-tool-use.sh" >/dev/null 2>&1; then
    printf 'pre-tool-use did not block destructive git reset\n'
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
