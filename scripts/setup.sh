#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
INSTALL_ROOT="$CODEX_HOME/skills/codex-framework-core"

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      cat <<EOF
usage: setup.sh

Installs framework skills and native custom-agent profiles for Codex.
EOF
      exit 0
      ;;
    *)
      echo "unknown setup option: $1" >&2
      exit 1
      ;;
  esac
  shift
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
mkdir -p "$CODEX_HOME/agents"
rm -rf "$INSTALL_ROOT"
mkdir -p "$INSTALL_ROOT"
while IFS= read -r skill; do
  case "$skill" in ''|'#'*) continue ;; esac
  [ -d "$REPO_DIR/skills/$skill" ] || { printf 'missing core skill: %s\n' "$skill" >&2; exit 1; }
  ln -sfn "$REPO_DIR/skills/$skill" "$INSTALL_ROOT/$skill"
done < "$REPO_DIR/skills/core.txt"
ln -sfn "$REPO_DIR" "$CODEX_HOME/frameworks/codex-framework"

for agent_file in "$REPO_DIR"/.codex/agents/*.toml; do
  [ -f "$agent_file" ] || continue
  ln -sfn "$agent_file" "$CODEX_HOME/agents/codex-framework-$(basename "$agent_file")"
done

cat <<EOF
Installed skills:
  $INSTALL_ROOT (curated native core from $REPO_DIR/skills/core.txt)
Installed native agents:
  $CODEX_HOME/agents/codex-framework-*.toml -> $REPO_DIR/.codex/agents/*.toml

Dependency check:
$(report_dep required codex "Codex CLI")
$(report_dep recommended rg "ripgrep")
$(report_dep recommended gh "GitHub CLI")
$(report_dep optional ast-grep "ast-grep")
$(report_dep optional jq "jq")

Next steps:
1. Use native Codex directly: codex, codex doctor, codex update, codex mcp, codex plugin, codex review
2. Start a new Codex session after installation so native skills and agents are discovered.
3. Keep domain-only skills in the source library and add them project-scoped only when a task needs them.
4. Use Codex directly for planning, issues, reviews, worktrees, plugins, and MCP.
5. Run bash "$REPO_DIR/scripts/framework-health.sh" after framework changes.
6. Configure runtime defaults in native Codex config or with native CLI flags.
EOF
