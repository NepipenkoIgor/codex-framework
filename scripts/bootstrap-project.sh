#!/bin/bash
set -euo pipefail

FRAMEWORK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_DIR="${1:-$PWD}"
TEMPLATE_DIR="$FRAMEWORK_ROOT/templates/project"
TARGET_CODEX_DIR="$TARGET_DIR/.codex"
TARGET_AGENTS="$TARGET_DIR/AGENTS.md"
TARGET_NATIVE_AGENTS="$TARGET_CODEX_DIR/agents"
TARGET_RULES="$TARGET_CODEX_DIR/rules"
TARGET_PACK_MANIFEST="$TARGET_CODEX_DIR/skill-packs.txt"

mkdir -p "$TARGET_NATIVE_AGENTS" "$TARGET_RULES"

if [ ! -e "$TARGET_AGENTS" ]; then
  cp "$TEMPLATE_DIR/AGENTS.md" "$TARGET_AGENTS"
fi

for agent_file in "$FRAMEWORK_ROOT"/.codex/agents/*.toml; do
  [ -f "$agent_file" ] || continue
  target_agent="$TARGET_NATIVE_AGENTS/$(basename "$agent_file")"
  [ -e "$target_agent" ] || cp "$agent_file" "$target_agent"
done

[ -e "$TARGET_RULES/safety.rules" ] || cp "$FRAMEWORK_ROOT/.codex/rules/safety.rules" "$TARGET_RULES/safety.rules"

if [ ! -e "$TARGET_PACK_MANIFEST" ]; then
  printf '%s\n' \
    '# One pack name per line. Available packs live in codex-framework/skills/packs/.' \
    '# Run codex-framework/scripts/framework-skill-sync.sh <project-root> after editing.' \
    > "$TARGET_PACK_MANIFEST"
fi

bash "$FRAMEWORK_ROOT/scripts/framework-skill-sync.sh" "$TARGET_DIR" >/dev/null

printf 'project instructions: %s\n' "$TARGET_AGENTS"
printf 'native agents: %s\n' "$TARGET_NATIVE_AGENTS"
printf 'native rules: %s\n' "$TARGET_RULES/safety.rules"
printf 'project skill packs: %s\n' "$TARGET_PACK_MANIFEST"
