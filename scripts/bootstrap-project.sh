#!/bin/bash
set -euo pipefail

FRAMEWORK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_DIR="${1:-$PWD}"
MODE="${2:-}"
TEMPLATE_DIR="$FRAMEWORK_ROOT/templates/project"
TARGET_CODEX="$TARGET_DIR/CODEX.md"
TARGET_CODEX_DIR="$TARGET_DIR/.codex"
TARGET_COMMANDS="$TARGET_CODEX_DIR/project.env"
TARGET_SPECS="$TARGET_CODEX_DIR/specs"
tmp_commands="$(mktemp)"
trap 'rm -f "$tmp_commands"' EXIT

mkdir -p "$TARGET_DIR"
mkdir -p "$TARGET_CODEX_DIR"
mkdir -p "$TARGET_SPECS"

changed=0

if [ ! -e "$TARGET_CODEX" ]; then
  cp "$TEMPLATE_DIR/CODEX.md" "$TARGET_CODEX"
  changed=1
fi

refresh_reason=""
bash "$FRAMEWORK_ROOT/scripts/detect-project-commands.sh" "$TARGET_DIR" > "$tmp_commands"

if [ ! -e "$TARGET_COMMANDS" ]; then
  cp "$tmp_commands" "$TARGET_COMMANDS"
  changed=1
  refresh_reason="created"
else
  auto_managed=false
  if grep -Eq '^PROJECT_COMMANDS_MODE="auto"$' "$TARGET_COMMANDS"; then
    auto_managed=true
  elif ! grep -Eq '^PROJECT_COMMANDS_MODE="manual"$' "$TARGET_COMMANDS" \
    && grep -Fq 'auto-generated on bootstrap from repo detection' "$TARGET_COMMANDS"; then
    auto_managed=true
  fi

  if [ "$auto_managed" = true ] && ! cmp -s "$tmp_commands" "$TARGET_COMMANDS"; then
    cp "$tmp_commands" "$TARGET_COMMANDS"
    changed=1
    refresh_reason="refreshed"
  fi
fi

if [ "$MODE" = "--silent" ]; then
  exit 0
fi

if [ "$changed" -eq 0 ]; then
  cat <<EOF
Project already bootstrapped:
  $TARGET_CODEX
  $TARGET_COMMANDS
  $TARGET_SPECS
EOF
  exit 0
fi

cat <<EOF
Bootstrapped project instructions:
  $TARGET_CODEX
Project command registry:
  $TARGET_COMMANDS
Project specs directory:
  $TARGET_SPECS

Next steps:
1. Review the project-specific rules in $TARGET_CODEX
2. Review $TARGET_COMMANDS (${refresh_reason:-unchanged})
3. Adjust $TARGET_COMMANDS only if the detected commands need overrides, then set PROJECT_COMMANDS_MODE="manual"
4. If package manager or scripts changed later, regenerate $TARGET_COMMANDS manually with:
   bash $FRAMEWORK_ROOT/scripts/detect-project-commands.sh "$TARGET_DIR" > "$TARGET_COMMANDS"
5. Review roles in $FRAMEWORK_ROOT/agents
6. Use skills from $FRAMEWORK_ROOT/skills
EOF
