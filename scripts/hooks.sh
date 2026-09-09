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
    if doctor_hooks >/dev/null 2>&1; then
      printf 'native hook config already valid: %s\n' "$TARGET_CONFIG"
      return 0
    fi
    printf 'existing config has no compatible native safety hook: %s\n' "$TARGET_CONFIG" >&2
    printf 'refusing to overwrite user configuration; merge the framework safety hook explicitly\n' >&2
    return 1
  fi

  mkdir -p "$TARGET_HOOKS_DIR"
  cp "$FRAMEWORK_ROOT/scripts/hooks/pre-tool-use.sh" "$TARGET_HOOKS_DIR/pre-tool-use.sh"

  cat > "$TARGET_CONFIG" <<EOF
[agents]
max_concurrent_threads_per_session = 4

[[hooks.PreToolUse]]
matcher = "^Bash$"

[[hooks.PreToolUse.hooks]]
type = "command"
command = 'bash "\$(git rev-parse --show-toplevel)/.codex/hooks/pre-tool-use.sh"'
timeout = 5
statusMessage = "Checking safety policy"
EOF
  printf '%s\n' "$TARGET_CONFIG"
}

doctor_hooks() {
  local failures=0 hook_dir="$TARGET_HOOKS_DIR" expected_command='bash "$(git rev-parse --show-toplevel)/.codex/hooks/pre-tool-use.sh"'
  [ -f "$TARGET_CONFIG" ] || { printf 'missing hook config: %s\n' "$TARGET_CONFIG"; return 1; }
  if [ "$TARGET_DIR" = "$FRAMEWORK_ROOT" ]; then
    hook_dir="$FRAMEWORK_ROOT/scripts/hooks"
    expected_command='bash "$(git rev-parse --show-toplevel)/scripts/hooks/pre-tool-use.sh"'
  fi
  [ -f "$hook_dir/pre-tool-use.sh" ] || { printf 'missing hook: pre-tool-use\n'; failures=$((failures + 1)); }
  cmp -s "$FRAMEWORK_ROOT/scripts/hooks/pre-tool-use.sh" "$hook_dir/pre-tool-use.sh" \
    || { printf 'drift: framework pre-tool hook content differs\n'; failures=$((failures + 1)); }
  python3 - "$TARGET_CONFIG" "$expected_command" <<'PY' \
    || { printf 'drift: exact framework Bash hook contract is missing\n'; failures=$((failures + 1)); }
import pathlib
import sys
import tomllib

config = tomllib.loads(pathlib.Path(sys.argv[1]).read_text())
expected_command = sys.argv[2]
groups = config.get("hooks", {}).get("PreToolUse", [])
valid = any(
    group.get("matcher") == "^Bash$"
    and any(
        hook.get("type") == "command"
        and hook.get("command") == expected_command
        and hook.get("timeout") == 5
        for hook in group.get("hooks", [])
    )
    for group in groups
)
raise SystemExit(0 if valid else 1)
PY
  if grep -q 'SessionStart\|PostToolUse\|UserPromptSubmit\|\[\[hooks\.Stop\]\]' "$TARGET_CONFIG"; then
    printf 'drift: unsupported lifecycle hook remains in %s\n' "$TARGET_CONFIG"
    failures=$((failures + 1))
  fi
  [ "$failures" -eq 0 ]
}

smoke_hooks() {
  local sample
  sample='{"tool":"Bash","command":"git status --short"}'
  printf '%s\n' "$sample" | bash "$FRAMEWORK_ROOT/scripts/hooks/pre-tool-use.sh" >/dev/null
  sample='{"tool":"Bash","command":"git checkout -b feat/hook-smoke"}'
  printf '%s\n' "$sample" | bash "$FRAMEWORK_ROOT/scripts/hooks/pre-tool-use.sh" >/dev/null
  sample='{"tool":"Bash","command":"git switch -c codex/hidden-agent"}'
  if printf '%s\n' "$sample" | bash "$FRAMEWORK_ROOT/scripts/hooks/pre-tool-use.sh" >/dev/null 2>&1; then
    printf 'pre-tool-use allowed an implementation-revealing branch name\n'
    return 1
  fi
  sample='{"tool":"Bash","command":"git reset --hard HEAD"}'
  if printf '%s\n' "$sample" | bash "$FRAMEWORK_ROOT/scripts/hooks/pre-tool-use.sh" >/dev/null 2>&1; then
    printf 'pre-tool-use did not block destructive git reset\n'
    return 1
  fi
  sample='{"tool":"Bash","command":"rm -rf /"}'
  if printf '%s\n' "$sample" | bash "$FRAMEWORK_ROOT/scripts/hooks/pre-tool-use.sh" >/dev/null 2>&1; then
    printf 'pre-tool-use did not block recursive root deletion\n'
    return 1
  fi
  sample="{\"tool\":\"Bash\",\"command\":\"rm -rf /tmp/codex-${CODEX_THREAD_ID:-hook-smoke}-fixture\"}"
  if ! CODEX_THREAD_ID="${CODEX_THREAD_ID:-hook-smoke}" printf '%s\n' "$sample" | CODEX_THREAD_ID="${CODEX_THREAD_ID:-hook-smoke}" bash "$FRAMEWORK_ROOT/scripts/hooks/pre-tool-use.sh" >/dev/null 2>&1; then
    printf 'pre-tool-use overblocked exact task-owned temporary cleanup\n'
    return 1
  fi
  sample='{"tool":"Bash","command":"rm -rf .github/workflows"}'
  if printf '%s\n' "$sample" | bash "$FRAMEWORK_ROOT/scripts/hooks/pre-tool-use.sh" >/dev/null 2>&1; then
    printf 'pre-tool-use allowed an unproven relative recursive removal\n'
    return 1
  fi
  for command in \
    'rm -rf /tmp/repo/.git' \
    'rm -rf -- /' \
    'rm -fr /' \
    'rm --no-preserve-root --recursive --force /' \
    'rm --recursive --force /' \
    'rm -r --force /' \
    'rm -rf "$HOME"' \
    'bash -c "rm -rf /"' \
    'rm -rf ${UNSET:-/}' \
    'rm -rf ${HOME:-/tmp}' \
    'rm -rf /*' \
    'r'\''\'\''m -rf /' \
    'OPTS=-rf rm $OPTS /' \
    'rm $OPTS /' \
    'rm -rf /tmp/codex-one/../codex-other' \
    'rm -rf /./' \
    'rm -rf /tmp/..'; do
    sample="{\"tool\":\"Bash\",\"command\":\"$command\"}"
    if printf '%s\n' "$sample" | bash "$FRAMEWORK_ROOT/scripts/hooks/pre-tool-use.sh" >/dev/null 2>&1; then
      printf 'pre-tool-use missed dangerous recursive removal: %s\n' "$command"
      return 1
    fi
  done
  printf 'hook smoke passed\n'
}

case "$cmd" in
  install) install_hooks ;;
  doctor) doctor_hooks ;;
  smoke) smoke_hooks ;;
  *) usage; exit 1 ;;
esac
