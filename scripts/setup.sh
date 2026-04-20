#!/bin/bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
INSTALL_ROOT="$CODEX_HOME/skills/ai-codex-framework"
BIN_DIR="$HOME/.local/bin"
GLOBAL_LAUNCHER="$BIN_DIR/codex-fw"
SHELL_RC="$HOME/.zshrc"
START_MARKER="# >>> ai-codex-framework >>>"
END_MARKER="# <<< ai-codex-framework <<<"

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
mkdir -p "$BIN_DIR"
rm -rf "$INSTALL_ROOT"
ln -sfn "$REPO_DIR/skills" "$INSTALL_ROOT"
ln -sfn "$REPO_DIR" "$CODEX_HOME/frameworks/ai-codex-framework" 2>/dev/null || true
ln -sfn "$REPO_DIR/scripts/codex-fw.sh" "$GLOBAL_LAUNCHER"

if [ -f "$SHELL_RC" ]; then
  if ! grep -Fq 'export PATH="$HOME/.local/bin:$PATH"' "$SHELL_RC"; then
    printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$SHELL_RC"
  fi
else
  printf 'export PATH="$HOME/.local/bin:$PATH"\n' > "$SHELL_RC"
fi

if grep -Fq "$START_MARKER" "$SHELL_RC"; then
  tmp_file="$(mktemp)"
  awk -v start="$START_MARKER" -v end="$END_MARKER" '
    $0 == start { skip=1; next }
    $0 == end { skip=0; next }
    skip != 1 { print }
  ' "$SHELL_RC" > "$tmp_file"
  mv "$tmp_file" "$SHELL_RC"
fi

cat >> "$SHELL_RC" <<EOF

$START_MARKER
# -w <issue>  create/open issue worktree, extract spec, and launch Codex there
codex() {
  if [ \$# -eq 0 ]; then
    codex-fw session
    return
  fi
  if [ "\$1" = "--raw" ]; then
    shift
    command codex "\$@"
    return
  fi
  if [ "\$1" = "-w" ] && [ \$# -ge 2 ]; then
    shift
    codex-fw work "\$1"
    return
  fi
  if { [ "\$1" = "--task" ] || [ "\$1" = "-t" ]; } && [ \$# -ge 2 ]; then
    shift
    codex-fw go "\$*"
    return
  fi
  command codex "\$@"
}
$END_MARKER
EOF

cat <<EOF
Installed skills:
  $INSTALL_ROOT -> $REPO_DIR/skills
Global launcher:
  $GLOBAL_LAUNCHER -> $REPO_DIR/scripts/codex-fw.sh

Dependency check:
$(report_dep required codex "Codex CLI")
$(report_dep recommended rg "ripgrep")
$(report_dep recommended gh "GitHub CLI")
$(report_dep optional ast-grep "ast-grep")
$(report_dep optional jq "jq")

Next steps:
1. Restart your shell or run: source "$SHELL_RC"
2. Valid wrapped commands are: codex | codex --task "fix login bug" | codex -w 424 | codex --raw
3. Do not use: codex -row or codex --row
4. In any repo, run: codex or codex-fw session
5. For task bootstrap, run: codex --task "fix login bug" or codex-fw go "fix login bug"
6. To bypass the framework and open plain Codex, run: codex --raw
7. For issue workflow with a sibling worktree, run: codex-fw work 424 or codex -w 424
8. To refresh a repo's detected commands manually, run: codex-fw refresh-commands
9. Generate a PR body with: codex-fw pr-body
10. Create a PR with gh using that body: codex-fw pr-create
11. Use $REPO_DIR/agents as role briefs for delegated work.
12. Run codex-fw health to validate the framework.
EOF
