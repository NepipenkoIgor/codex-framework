#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
INSTALL_ROOT="$CODEX_HOME/skills/codex-framework-core"
PACK_ROOT="$CODEX_HOME/skills/codex-framework-packs"
GLOBAL_GUIDANCE_SOURCE="$REPO_DIR/templates/global/AGENTS.md"
GLOBAL_GUIDANCE_TARGET="$CODEX_HOME/AGENTS.md"
SELECTED_PACKS=""

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      cat <<EOF
usage: setup.sh [--pack NAME]...

Installs the universal framework core and optional project/domain packs.
Available packs: $(find "$REPO_DIR/skills/packs" -maxdepth 1 -name '*.txt' -exec basename {} .txt \; | sort | tr '\n' ' ')
EOF
      exit 0
      ;;
    --pack)
      [ $# -ge 2 ] || { echo "--pack requires a pack name" >&2; exit 1; }
      SELECTED_PACKS="$SELECTED_PACKS $2"
      shift
      ;;
    *)
      echo "unknown setup option: $1" >&2
      exit 1
      ;;
  esac
  shift
done

# Validate the complete request before replacing an existing pack installation.
for pack in $SELECTED_PACKS; do
  manifest="$REPO_DIR/skills/packs/$pack.txt"
  [ -f "$manifest" ] || { printf 'unknown skill pack: %s\n' "$pack" >&2; exit 1; }
  while IFS= read -r skill; do
    case "$skill" in ''|'#'*) continue ;; esac
    [ -d "$REPO_DIR/skills/$skill" ] || { printf 'missing skill in pack %s: %s\n' "$pack" "$skill" >&2; exit 1; }
  done < "$manifest"
done

version_line() {
  "$1" --version 2>/dev/null | head -n 1
}

install_hint() {
  local tool="$1"
  case "$tool" in
    codex) echo "Install Codex CLI first, then rerun setup." ;;
    rg) echo "Install: brew install ripgrep" ;;
    gh) echo "Install: brew install gh" ;;
    ast-grep) echo "Install: brew install ast-grep" ;;
    jq) echo "Install: brew install jq" ;;
    *) echo "Install the tool and rerun setup." ;;
  esac
}

report_dep() {
  local level="$1"
  local cmd="$2"
  local label="$3"
  if command -v "$cmd" >/dev/null 2>&1; then
    printf '   ✓ [%s] %s (%s)\n' "$level" "$label" "$(version_line "$cmd")"
  else
    printf '   %s [%s] %s not found\n' "$( [ "$level" = required ] && printf '✗' || printf '⬜' )" "$level" "$label"
    printf '     %s\n' "$(install_hint "$cmd")"
  fi
}

mkdir -p "$CODEX_HOME/skills"
mkdir -p "$CODEX_HOME/frameworks"
mkdir -p "$CODEX_HOME/bin"
mkdir -p "$CODEX_HOME/agents"
mkdir -p "$CODEX_HOME/rules"
rm -rf "$INSTALL_ROOT"
mkdir -p "$INSTALL_ROOT"
while IFS= read -r skill; do
  case "$skill" in ''|'#'*) continue ;; esac
  [ -d "$REPO_DIR/skills/$skill" ] || { printf 'missing core skill: %s\n' "$skill" >&2; exit 1; }
  ln -sfn "$REPO_DIR/skills/$skill" "$INSTALL_ROOT/$skill"
done < "$REPO_DIR/skills/core.txt"

rm -rf "$PACK_ROOT"
mkdir -p "$PACK_ROOT"
for pack in $SELECTED_PACKS; do
  manifest="$REPO_DIR/skills/packs/$pack.txt"
  pack_dir="$PACK_ROOT/$pack"
  mkdir -p "$pack_dir"
  while IFS= read -r skill; do
    case "$skill" in ''|'#'*) continue ;; esac
    ln -sfn "$REPO_DIR/skills/$skill" "$pack_dir/$skill"
  done < "$manifest"
done
ln -sfn "$REPO_DIR" "$CODEX_HOME/frameworks/codex-framework"
ln -sfn "$REPO_DIR/scripts/framework-stack-context.py" "$CODEX_HOME/bin/codex-framework-stack-context"

rm -f "$CODEX_HOME/agents"/codex-framework-*.toml
for agent_file in "$REPO_DIR"/.codex/agents/*.toml; do
  [ -f "$agent_file" ] || continue
  ln -sfn "$agent_file" "$CODEX_HOME/agents/codex-framework-$(basename "$agent_file")"
done
ln -sfn "$REPO_DIR/.codex/rules/safety.rules" "$CODEX_HOME/rules/codex-framework-safety.rules"

if [ -e "$GLOBAL_GUIDANCE_TARGET" ] || [ -L "$GLOBAL_GUIDANCE_TARGET" ]; then
  if [ "$GLOBAL_GUIDANCE_TARGET" -ef "$GLOBAL_GUIDANCE_SOURCE" ]; then
    GLOBAL_GUIDANCE_STATUS="$GLOBAL_GUIDANCE_TARGET -> $GLOBAL_GUIDANCE_SOURCE"
  else
    GLOBAL_GUIDANCE_STATUS="preserved existing user guidance: $GLOBAL_GUIDANCE_TARGET"
  fi
else
  ln -sfn "$GLOBAL_GUIDANCE_SOURCE" "$GLOBAL_GUIDANCE_TARGET"
  GLOBAL_GUIDANCE_STATUS="$GLOBAL_GUIDANCE_TARGET -> $GLOBAL_GUIDANCE_SOURCE"
fi

cat <<EOF
Installed skills:
  $INSTALL_ROOT (curated native core from $REPO_DIR/skills/core.txt)
  $PACK_ROOT (selected packs:${SELECTED_PACKS:- none})
Installed native agents:
  $CODEX_HOME/agents/codex-framework-*.toml -> $REPO_DIR/.codex/agents/*.toml
Installed native rules:
  $CODEX_HOME/rules/codex-framework-safety.rules -> $REPO_DIR/.codex/rules/safety.rules
Installed dynamic stack resolver:
  $CODEX_HOME/bin/codex-framework-stack-context -> $REPO_DIR/scripts/framework-stack-context.py
Packaged plugin:
  $REPO_DIR/plugins/ai-codex-framework (optional hooks bundle; curated skills remain unchanged)
Installed global guidance:
  $GLOBAL_GUIDANCE_STATUS

Dependency check:
$(report_dep required codex "Codex CLI")
$(report_dep recommended rg "ripgrep")
$(report_dep recommended gh "GitHub CLI")
$(report_dep optional ast-grep "ast-grep")
$(report_dep optional jq "jq")

Next steps:
1. Use native Codex directly: codex, codex doctor, codex update, codex mcp, codex plugin, codex review
2. Start a new Codex session after installation so native skills and agents are discovered.
3. Install domain-only packs explicitly with --pack, or add individual skills project-scoped when a task needs them.
4. Use Codex directly for planning, issues, reviews, worktrees, plugins, and MCP.
5. Run bash "$REPO_DIR/scripts/framework-health.sh" after framework changes.
6. Enable native memories and multi-agent V2 in user config; use the same project config from Desktop and CLI.
EOF
