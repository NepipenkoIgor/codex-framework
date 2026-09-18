#!/bin/bash
set -euo pipefail

# Fail before using required tools or touching installation paths.
for dependency in python3 git codex; do
  command -v "$dependency" >/dev/null 2>&1 || {
    printf 'Required dependency missing: %s. Install it using your OS package manager, then rerun setup.\n' "$dependency" >&2
    exit 1
  }
done
python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)' || {
  printf 'Python 3.11 or newer must be available as python3 on PATH; select a compatible interpreter and rerun this command.\n' >&2
  exit 1
}

# Preflight must not create Python caches in a fresh user home.
export PYTHONDONTWRITEBYTECODE=1

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FRAMEWORK_CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
USER_SKILLS_ROOT="${CODEX_SKILLS_HOME:-$HOME/.agents/skills}"
FRAMEWORK_CODEX_HOME="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).expanduser().resolve(strict=False))' "$FRAMEWORK_CODEX_HOME")"
USER_SKILLS_ROOT="$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).expanduser().resolve(strict=False))' "$USER_SKILLS_ROOT")"
LEGACY_INSTALL_ROOT="$FRAMEWORK_CODEX_HOME/skills/codex-framework-core"
LEGACY_PACK_ROOT="$FRAMEWORK_CODEX_HOME/skills/codex-framework-packs"
INSTALL_STATE="$USER_SKILLS_ROOT/.codex-framework-install.json"
LINK_STATE="$FRAMEWORK_CODEX_HOME/frameworks/.codex-framework-links.json"
GLOBAL_GUIDANCE_SOURCE="$REPO_DIR/templates/global/AGENTS.md"
GLOBAL_GUIDANCE_TARGET="$FRAMEWORK_CODEX_HOME/AGENTS.md"
SELECTED_PACKS=""
SOURCE_ARGS=(--root "$REPO_DIR")

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help)
      cat <<EOF
usage: setup.sh [--development] [--pack NAME]...

Default: copy clean detached Git source into a durable independent release clone. --development explicitly links mutable source.

Installs the universal framework core and optional project/domain packs.
Available packs: $(find "$REPO_DIR/skills/packs" -maxdepth 1 -name '*.txt' -exec basename {} .txt \; | sort | tr '\n' ' ')
EOF
      exit 0
      ;;
    --development)
      SOURCE_ARGS+=(--development)
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

python3 "$REPO_DIR/scripts/framework-install-source.py" "${SOURCE_ARGS[@]}"

SELECTED_PACKS="$(printf '%s' "$SELECTED_PACKS" | tr ' ' '\n' | awk 'NF && !seen[$0]++' | sort | tr '\n' ' ')"

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
    rg) echo "Install ripgrep using your OS package manager." ;;
    gh) echo "Install GitHub CLI using your OS package manager." ;;
    ast-grep) echo "Install ast-grep using your OS package manager." ;;
    jq) echo "Install jq using your OS package manager." ;;
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

build_install_args() {
  GLOBAL_GUIDANCE_SOURCE="$REPO_DIR/templates/global/AGENTS.md"
  link_args=(
    --state "$LINK_STATE"
    --source-root "$REPO_DIR"
    --guidance "$GLOBAL_GUIDANCE_TARGET=$GLOBAL_GUIDANCE_SOURCE"
    --link "$FRAMEWORK_CODEX_HOME/frameworks/codex-framework=$REPO_DIR"
    --link "$FRAMEWORK_CODEX_HOME/bin/codex-framework-stack-context=$REPO_DIR/scripts/framework-stack-context.py"
    --link "$FRAMEWORK_CODEX_HOME/bin/codex-framework-doctor=$REPO_DIR/scripts/framework-doctor.sh"
    --link "$FRAMEWORK_CODEX_HOME/rules/codex-framework-safety.rules=$REPO_DIR/.codex/rules/safety.rules"
  )
  if [[ " ${SOURCE_ARGS[*]} " == *" --development "* ]]; then
    link_args+=(--development)
  fi
  profile_args=(
    --file "$FRAMEWORK_CODEX_HOME/agents/codex-framework-architect.toml=$REPO_DIR/.codex/agents/architect.toml"
    --file "$FRAMEWORK_CODEX_HOME/agents/codex-framework-reviewer.toml=$REPO_DIR/.codex/agents/reviewer.toml"
    --file "$FRAMEWORK_CODEX_HOME/agents/codex-framework-tester.toml=$REPO_DIR/.codex/agents/tester.toml"
  )

  install_args=(
    --root "$REPO_DIR"
    --skills-root "$USER_SKILLS_ROOT"
    --state "$INSTALL_STATE"
    --core "$REPO_DIR/skills/core.txt"
    --legacy-root "$LEGACY_INSTALL_ROOT"
    --legacy-root "$LEGACY_PACK_ROOT"
  )
  for pack in $SELECTED_PACKS; do
    install_args+=(--pack "$pack")
  done
}
build_install_args
# Check every destination before creating even the durable release directory.
python3 "$REPO_DIR/scripts/framework-link-install.py" --preflight "${link_args[@]}" "${profile_args[@]}"
python3 "$REPO_DIR/scripts/framework-install.py" --preflight "${install_args[@]}"
if [[ " ${SOURCE_ARGS[*]} " != *" --development "* ]]; then
  REPO_DIR="$(python3 "$REPO_DIR/scripts/framework-install-source.py" --root "$REPO_DIR" --materialize "$FRAMEWORK_CODEX_HOME/frameworks/releases")"
  build_install_args
fi
python3 "$REPO_DIR/scripts/framework-install.py" "${install_args[@]}"

python3 "$REPO_DIR/scripts/framework-link-install.py" "${link_args[@]}" "${profile_args[@]}"

GLOBAL_GUIDANCE_STATUS="$GLOBAL_GUIDANCE_TARGET (managed link; setup fails closed on unmanaged guidance)"

cat <<EOF
Installed skills:
  $USER_SKILLS_ROOT (direct native USER skills; selected global packs:${SELECTED_PACKS:- none})
Removed legacy framework skill namespaces:
  $LEGACY_INSTALL_ROOT
  $LEGACY_PACK_ROOT
Installed native agents:
  $FRAMEWORK_CODEX_HOME/agents/codex-framework-*.toml (managed copies from $REPO_DIR/.codex/agents/*.toml)
Installed native rules:
  $FRAMEWORK_CODEX_HOME/rules/codex-framework-safety.rules -> $REPO_DIR/.codex/rules/safety.rules
Installed dynamic stack resolver:
  $FRAMEWORK_CODEX_HOME/bin/codex-framework-stack-context -> $REPO_DIR/scripts/framework-stack-context.py
Installed effective-state doctor:
  $FRAMEWORK_CODEX_HOME/bin/codex-framework-doctor -> $REPO_DIR/scripts/framework-doctor.sh
Packaged plugin:
  $REPO_DIR/.agents/plugins/marketplace.json (native plugin marketplace; curated skills remain unchanged)
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
3. Install domain-only packs project-scoped with scripts/framework-skill-sync.sh, or pass --pack for an intentionally global pack.
4. Use Codex directly for planning, issues, reviews, worktrees, plugins, and MCP.
5. Run bash "$REPO_DIR/scripts/framework-health.sh" after framework changes.
6. Enable native memories only if you want optional recall; current native subagent workflows are enabled by default.
EOF
