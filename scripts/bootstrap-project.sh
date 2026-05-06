#!/bin/bash
set -euo pipefail

FRAMEWORK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$FRAMEWORK_ROOT/scripts/lib.sh"
TARGET_DIR="${1:-$PWD}"
MODE="${2:-}"
TEMPLATE_DIR="$FRAMEWORK_ROOT/templates/project"
TARGET_CODEX="$TARGET_DIR/CODEX.md"
TARGET_CODEX_DIR="$TARGET_DIR/.codex"
TARGET_COMMANDS="$TARGET_CODEX_DIR/project.env"
TARGET_SPECS="$TARGET_CODEX_DIR/specs"
TARGET_CACHE="$TARGET_CODEX_DIR/cache"
TARGET_MEMORY="$TARGET_CODEX_DIR/memory"
tmp_commands="$(mktemp)"
trap 'rm -f "$tmp_commands"' EXIT

project_package_manager() {
  if [ -f "$TARGET_DIR/bun.lockb" ] || [ -f "$TARGET_DIR/bun.lock" ]; then
    printf 'bun\n'
    return 0
  fi
  if [ -f "$TARGET_DIR/pnpm-lock.yaml" ]; then
    printf 'pnpm\n'
    return 0
  fi
  if [ -f "$TARGET_DIR/yarn.lock" ]; then
    printf 'yarn\n'
    return 0
  fi
  if [ -f "$TARGET_DIR/package.json" ]; then
    local package_manager
    package_manager="$(
      python3 - <<PY 2>/dev/null || true
import json
from pathlib import Path

package_json = Path("$TARGET_DIR/package.json")
try:
    data = json.loads(package_json.read_text(encoding="utf-8"))
except Exception:
    raise SystemExit(0)

value = str(data.get("packageManager", "")).strip()
if not value:
    raise SystemExit(0)
print(value.split("@", 1)[0].strip())
PY
    )"
    case "$package_manager" in
      bun|pnpm|yarn)
        printf '%s\n' "$package_manager"
        return 0
        ;;
    esac
  fi
  printf 'npm\n'
}

project_needs_dependency_install() {
  [ -f "$TARGET_DIR/package.json" ] || return 1
  [ -d "$TARGET_DIR/node_modules" ] || return 0
  [ ! -x "$TARGET_DIR/node_modules/.bin/eslint" ] && return 0
  [ ! -x "$TARGET_DIR/node_modules/.bin/lint-staged" ] && return 0
  return 1
}

project_needs_dotnet_restore() {
  find "$TARGET_DIR" -maxdepth 3 -path '*/obj/project.assets.json' -type f | grep -q . && return 1
  find "$TARGET_DIR" -maxdepth 1 \( -name '*.csproj' -o -name '*.sln' \) | grep -q .
}

project_needs_flutter_pub_get() {
  [ -f "$TARGET_DIR/pubspec.yaml" ] || return 1
  [ -f "$TARGET_DIR/.dart_tool/package_config.json" ] || return 0
  return 1
}

install_project_dependencies() {
  local pm cmd
  pm="$(project_package_manager)"
  case "$pm" in
    bun)
      has_command bun || fail "bun is required to install project dependencies"
      cmd="bun install"
      ;;
    pnpm)
      has_command pnpm || fail "pnpm is required to install project dependencies"
      cmd="pnpm install"
      [ -f "$TARGET_DIR/pnpm-lock.yaml" ] && cmd="pnpm install --frozen-lockfile"
      ;;
    yarn)
      has_command yarn || fail "yarn is required to install project dependencies"
      cmd="yarn install"
      [ -f "$TARGET_DIR/yarn.lock" ] && cmd="yarn install --frozen-lockfile"
      ;;
    npm|*)
      has_command npm || fail "npm is required to install project dependencies"
      if [ -f "$TARGET_DIR/package-lock.json" ]; then
        cmd="npm ci"
      else
        cmd="npm install"
      fi
      ;;
  esac

  print_section "Dependencies"
  info "package manager: $pm"
  info "install command: $cmd"
  (
    cd "$TARGET_DIR"
    run_with_spinner "install project dependencies" bash -lc "$cmd"
  )
}

install_dotnet_restore() {
  local target
  if ! has_command dotnet; then
    fail "dotnet is required to restore .NET dependencies"
  fi

  target=""
  if find "$TARGET_DIR" -maxdepth 1 -name '*.sln' | grep -q .; then
    target="$(find "$TARGET_DIR" -maxdepth 1 -name '*.sln' | head -n1)"
  elif find "$TARGET_DIR" -maxdepth 1 -name '*.csproj' | grep -q .; then
    target="$(find "$TARGET_DIR" -maxdepth 1 -name '*.csproj' | head -n1)"
  fi

  print_section ".NET"
  info "command: dotnet restore${target:+ $target}"
  if [ -n "$target" ]; then
    (
      cd "$TARGET_DIR"
      run_with_spinner ".NET restore" dotnet restore "$target"
    )
  else
    (
      cd "$TARGET_DIR"
      run_with_spinner ".NET restore" dotnet restore
    )
  fi
}

install_flutter_dependencies() {
  if ! has_command flutter; then
    fail "flutter is required to fetch Flutter dependencies"
  fi

  print_section "Flutter"
  info "command: flutter pub get"
  (
    cd "$TARGET_DIR"
    run_with_spinner "flutter pub get" flutter pub get
  )
}

mkdir -p "$TARGET_DIR"
mkdir -p "$TARGET_CODEX_DIR"
mkdir -p "$TARGET_SPECS"
mkdir -p "$TARGET_CACHE" >/dev/null 2>&1 || true
mkdir -p "$TARGET_MEMORY" >/dev/null 2>&1 || true

changed=0

if [ ! -e "$TARGET_CODEX" ]; then
  cp "$TEMPLATE_DIR/CODEX.md" "$TARGET_CODEX"
  changed=1
fi

if git -C "$TARGET_DIR" rev-parse --show-toplevel >/dev/null 2>&1; then
  TARGET_HOOKS="$(ensure_project_git_hooks "$TARGET_DIR")"
  cp "$TEMPLATE_DIR/.githooks/pre-commit" "$TARGET_HOOKS/pre-commit"
  cp "$TEMPLATE_DIR/.githooks/commit-msg" "$TARGET_HOOKS/commit-msg"
  chmod +x "$TARGET_HOOKS/pre-commit" "$TARGET_HOOKS/commit-msg"

  current_hooks="$(git -C "$TARGET_DIR" config --local --get core.hooksPath 2>/dev/null || true)"
  if [ "$current_hooks" = ".githooks" ]; then
    git -C "$TARGET_DIR" config --local --unset core.hooksPath >/dev/null 2>&1 || true
  fi

  if [ -d "$TARGET_DIR/.githooks" ] && ! git -C "$TARGET_DIR" ls-files --error-unmatch .githooks >/dev/null 2>&1; then
    rm -rf "$TARGET_DIR/.githooks"
  fi
fi

if [ "${CODEX_SKIP_DEP_INSTALL:-0}" != "1" ] && project_needs_dependency_install; then
  install_project_dependencies
fi

if [ "${CODEX_SKIP_DEP_INSTALL:-0}" != "1" ] && project_needs_dotnet_restore; then
  install_dotnet_restore
fi

if [ "${CODEX_SKIP_DEP_INSTALL:-0}" != "1" ] && project_needs_flutter_pub_get; then
  install_flutter_dependencies
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
  $TARGET_MEMORY
  $(git -C "$TARGET_DIR" rev-parse --git-path hooks 2>/dev/null || printf '%s/.git/hooks' "$TARGET_DIR")
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
Project memory directory:
  $TARGET_MEMORY
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
8. Repo-local git hooks are installed in the repository's git hooks directory when this is a git repo
EOF
