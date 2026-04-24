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
TARGET_CACHE="$TARGET_CODEX_DIR/cache"
TARGET_HOOKS="$TARGET_DIR/.githooks"
tmp_commands="$(mktemp)"
trap 'rm -f "$tmp_commands"' EXIT

mkdir -p "$TARGET_DIR"
mkdir -p "$TARGET_CODEX_DIR"
mkdir -p "$TARGET_SPECS"
mkdir -p "$TARGET_CACHE" >/dev/null 2>&1 || true
mkdir -p "$TARGET_HOOKS"

changed=0

if [ ! -e "$TARGET_CODEX" ]; then
  cp "$TEMPLATE_DIR/CODEX.md" "$TARGET_CODEX"
  changed=1
fi

cp "$TEMPLATE_DIR/.githooks/pre-commit" "$TARGET_HOOKS/pre-commit"
cp "$TEMPLATE_DIR/.githooks/commit-msg" "$TARGET_HOOKS/commit-msg"
chmod +x "$TARGET_HOOKS/pre-commit" "$TARGET_HOOKS/commit-msg"

if git -C "$TARGET_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
  current_hooks="$(git -C "$TARGET_DIR" config --local --get core.hooksPath 2>/dev/null || true)"
  if [ -z "$current_hooks" ] || [ "$current_hooks" = ".githooks" ]; then
    git -C "$TARGET_DIR" config --local core.hooksPath .githooks >/dev/null 2>&1 || true
  fi
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
  tmp_intel="$(mktemp)"
  mkdir -p "$(dirname "$TARGET_CACHE/repo-intelligence.env")" >/dev/null 2>&1 || true
  if bash "$FRAMEWORK_ROOT/scripts/detect-repo-intelligence.sh" "$TARGET_DIR" > "$tmp_intel" 2>/dev/null; then
    mv "$tmp_intel" "$TARGET_CACHE/repo-intelligence.env" 2>/dev/null || rm -f "$tmp_intel"
  else
    rm -f "$tmp_intel"
  fi
  exit 0
fi

if [ "$changed" -eq 0 ]; then
  cat <<EOF
Project already bootstrapped:
  $TARGET_CODEX
  $TARGET_COMMANDS
  $TARGET_SPECS
  $TARGET_CACHE
  $TARGET_HOOKS
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
Project cache directory:
  $TARGET_CACHE
Project git hooks:
  $TARGET_HOOKS

Next steps:
1. Review the project-specific rules in $TARGET_CODEX
2. Review $TARGET_COMMANDS (${refresh_reason:-unchanged})
3. Adjust $TARGET_COMMANDS only if the detected commands need overrides, then set PROJECT_COMMANDS_MODE="manual"
4. If package manager or scripts changed later, regenerate $TARGET_COMMANDS manually with:
   bash $FRAMEWORK_ROOT/scripts/detect-project-commands.sh "$TARGET_DIR" > "$TARGET_COMMANDS"
5. Repo intelligence cache:
   $TARGET_CACHE/repo-intelligence.env
6. Review roles in $FRAMEWORK_ROOT/agents
7. Use skills from $FRAMEWORK_ROOT/skills
8. Repo-local git hooks are installed through core.hooksPath=.githooks when this is a git repo
EOF
