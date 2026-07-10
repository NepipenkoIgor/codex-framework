#!/bin/bash
set -euo pipefail

FRAMEWORK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_DIR="${1:-$PWD}"
TEMPLATE_DIR="$FRAMEWORK_ROOT/templates/project"
TARGET_CODEX_DIR="$TARGET_DIR/.codex"
TARGET_AGENTS="$TARGET_DIR/AGENTS.md"
TARGET_NATIVE_AGENTS="$TARGET_CODEX_DIR/agents"

mkdir -p "$TARGET_NATIVE_AGENTS"

if [ ! -e "$TARGET_AGENTS" ]; then
  cp "$TEMPLATE_DIR/AGENTS.md" "$TARGET_AGENTS"
fi

for agent_file in "$FRAMEWORK_ROOT"/.codex/agents/*.toml; do
  [ -f "$agent_file" ] || continue
  target_agent="$TARGET_NATIVE_AGENTS/$(basename "$agent_file")"
  [ -e "$target_agent" ] || cp "$agent_file" "$target_agent"
done

bash "$FRAMEWORK_ROOT/scripts/hooks.sh" install "$TARGET_DIR" >/dev/null

printf 'project instructions: %s\n' "$TARGET_AGENTS"
printf 'native agents: %s\n' "$TARGET_NATIVE_AGENTS"
printf 'hook config: %s\n' "$TARGET_CODEX_DIR/config.toml"
