#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

usage() {
  cat <<EOF
usage: hooks.sh <install|doctor|smoke> [path]
EOF
}

cmd="${1:-}"
[ -n "$cmd" ] || {
  usage
  exit 1
}
shift || true

TARGET_DIR="$(cd "${1:-$(project_root)}" && pwd)"
FRAMEWORK_ROOT="$(framework_root)"
TARGET_CODEX_DIR="$TARGET_DIR/.codex"
TARGET_HOOKS_JSON="$TARGET_CODEX_DIR/hooks.json"
TARGET_CONFIG="$TARGET_CODEX_DIR/config.toml"

json_path_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

install_hooks() {
  local tmp
  if ! mkdir -p "$TARGET_CODEX_DIR" "$TARGET_CODEX_DIR/hooks" 2>/dev/null; then
    fail "cannot write $TARGET_CODEX_DIR; Codex hook install is required"
  fi
  tmp="$(mktemp)"

  cat > "$tmp" <<EOF
{
  "SessionStart": [
    {
      "matcher": "startup|resume|clear|.*",
      "hooks": [
        {
          "type": "command",
          "command": "bash '$(json_path_escape "$FRAMEWORK_ROOT")/scripts/hooks/session-start.sh'",
          "timeout": 15,
          "statusMessage": "Codex framework session context"
        }
      ]
    }
  ],
  "UserPromptSubmit": [
    {
      "matcher": ".*",
      "hooks": [
        {
          "type": "command",
          "command": "bash '$(json_path_escape "$FRAMEWORK_ROOT")/scripts/hooks/user-prompt-submit.sh'",
          "timeout": 10,
          "statusMessage": "Codex framework route"
        }
      ]
    }
  ],
  "PreToolUse": [
    {
      "matcher": ".*",
      "hooks": [
        {
          "type": "command",
          "command": "bash '$(json_path_escape "$FRAMEWORK_ROOT")/scripts/hooks/pre-tool-use.sh'",
          "timeout": 5,
          "statusMessage": "Codex framework guard"
        }
      ]
    }
  ],
  "PostToolUse": [
    {
      "matcher": ".*",
      "hooks": [
        {
          "type": "command",
          "command": "bash '$(json_path_escape "$FRAMEWORK_ROOT")/scripts/hooks/post-tool-use.sh'",
          "timeout": 5,
          "statusMessage": "Codex framework change tracker"
        }
      ]
    }
  ],
  "Stop": [
    {
      "matcher": ".*",
      "hooks": [
        {
          "type": "command",
          "command": "bash '$(json_path_escape "$FRAMEWORK_ROOT")/scripts/hooks/stop.sh'",
          "timeout": 30,
          "statusMessage": "Codex framework stop checks"
        }
      ]
    }
  ]
}
EOF

  if [ ! -f "$TARGET_HOOKS_JSON" ] || ! cmp -s "$tmp" "$TARGET_HOOKS_JSON"; then
    mv "$tmp" "$TARGET_HOOKS_JSON"
  else
    rm -f "$tmp"
  fi

  local fw
  fw="$(json_path_escape "$FRAMEWORK_ROOT")"
  local toml_block
  toml_block="$(cat <<TOMLEOF

[[hooks.SessionStart]]
matcher = "startup|resume|clear|.*"

[[hooks.SessionStart.hooks]]
type = "command"
command = "bash '${fw}/scripts/hooks/session-start.sh'"
timeout = 15
statusMessage = "Codex framework session context"

[[hooks.UserPromptSubmit]]
matcher = ".*"

[[hooks.UserPromptSubmit.hooks]]
type = "command"
command = "bash '${fw}/scripts/hooks/user-prompt-submit.sh'"
timeout = 10
statusMessage = "Codex framework route"

[[hooks.PreToolUse]]
matcher = ".*"

[[hooks.PreToolUse.hooks]]
type = "command"
command = "bash '${fw}/scripts/hooks/pre-tool-use.sh'"
timeout = 5
statusMessage = "Codex framework guard"

[[hooks.PostToolUse]]
matcher = ".*"

[[hooks.PostToolUse.hooks]]
type = "command"
command = "bash '${fw}/scripts/hooks/post-tool-use.sh'"
timeout = 5
statusMessage = "Codex framework change tracker"

[[hooks.Stop]]
matcher = ".*"

[[hooks.Stop.hooks]]
type = "command"
command = "bash '${fw}/scripts/hooks/stop.sh'"
timeout = 30
statusMessage = "Codex framework stop checks"
TOMLEOF
)"

  if [ ! -f "$TARGET_CONFIG" ]; then
    printf '%s\n' "$toml_block" > "$TARGET_CONFIG"
  elif grep -Eq '^\[\[hooks\.' "$TARGET_CONFIG"; then
    :
  else
    printf '%s\n' "$toml_block" >> "$TARGET_CONFIG"
  fi

  printf '%s\n' "$TARGET_HOOKS_JSON"
}

doctor_hooks() {
  local failures=0
  print_section "Codex Hooks"
  if [ -f "$TARGET_HOOKS_JSON" ]; then
    info "hooks.json: $TARGET_HOOKS_JSON"
  else
    warn "hooks.json missing: $TARGET_HOOKS_JSON"
    failures=$((failures + 1))
  fi
  if [ -f "$TARGET_CONFIG" ]; then
    if grep -Eq '^\[\[hooks\.' "$TARGET_CONFIG"; then
      info "config.toml hooks: inline TOML blocks present"
    else
      warn "config.toml has no [[hooks.*]] blocks — run: hooks.sh install"
      failures=$((failures + 1))
    fi
  else
    warn "config.toml missing: $TARGET_CONFIG"
    failures=$((failures + 1))
  fi
  if has_command jq && [ -f "$TARGET_HOOKS_JSON" ]; then
    if jq empty "$TARGET_HOOKS_JSON" >/dev/null 2>&1; then
      info "hooks.json syntax: valid"
    else
      warn "hooks.json syntax: invalid"
      failures=$((failures + 1))
    fi
  elif ! has_command jq; then
    warn "jq unavailable; skipping hooks.json validation"
  fi
  for hook in session-start user-prompt-submit pre-tool-use post-tool-use stop; do
    if [ -x "$FRAMEWORK_ROOT/scripts/hooks/$hook.sh" ]; then
      info "hook script: $hook ok"
    else
      warn "hook script missing or not executable: $hook"
      failures=$((failures + 1))
    fi
  done
  info "runtime note: hooks are the required lifecycle path for this framework"
  [ "$failures" -eq 0 ]
}

smoke_hooks() {
  local sample
  sample='{"prompt":"review framework hook architecture","tool":"Bash","command":"git status --short"}'
  printf '%s\n' "$sample" | "$FRAMEWORK_ROOT/scripts/hooks/user-prompt-submit.sh" >/dev/null
  printf '%s\n' "$sample" | "$FRAMEWORK_ROOT/scripts/hooks/pre-tool-use.sh" >/dev/null
  printf '%s\n' "$sample" | "$FRAMEWORK_ROOT/scripts/hooks/post-tool-use.sh" >/dev/null
  printf 'hook smoke passed\n'
}

case "$cmd" in
  install) install_hooks ;;
  doctor) doctor_hooks ;;
  smoke) smoke_hooks ;;
  -h|--help) usage ;;
  *) usage; exit 1 ;;
esac
