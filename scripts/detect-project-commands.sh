#!/bin/bash
set -euo pipefail

ROOT="${1:-$PWD}"

package_manager_from_package_json() {
  [ -f "$ROOT/package.json" ] || return 1
  python3 - <<PY 2>/dev/null
import json
from pathlib import Path

package_json = Path("$ROOT/package.json")
try:
    data = json.loads(package_json.read_text(encoding="utf-8"))
except Exception:
    raise SystemExit(1)

value = str(data.get("packageManager", "")).strip()
if not value:
    raise SystemExit(1)
print(value.split("@", 1)[0].strip())
PY
}

pkg_runner_value() {
  if [ -f "$ROOT/bun.lockb" ] || [ -f "$ROOT/bun.lock" ]; then
    printf 'bun run'
    return 0
  fi
  if [ -f "$ROOT/pnpm-lock.yaml" ]; then
    printf 'pnpm'
    return 0
  fi
  if [ -f "$ROOT/yarn.lock" ]; then
    printf 'yarn'
    return 0
  fi
  case "$(package_manager_from_package_json || true)" in
    bun) printf 'bun run'; return 0 ;;
    pnpm) printf 'pnpm'; return 0 ;;
    yarn) printf 'yarn'; return 0 ;;
  esac
  printf 'npm run'
}

pkg_exec_value() {
  if [ -f "$ROOT/bun.lockb" ] || [ -f "$ROOT/bun.lock" ]; then
    printf 'bunx'
    return 0
  fi
  if [ -f "$ROOT/pnpm-lock.yaml" ]; then
    printf 'pnpm exec'
    return 0
  fi
  if [ -f "$ROOT/yarn.lock" ]; then
    printf 'yarn'
    return 0
  fi
  case "$(package_manager_from_package_json || true)" in
    bun) printf 'bunx'; return 0 ;;
    pnpm) printf 'pnpm exec'; return 0 ;;
    yarn) printf 'yarn'; return 0 ;;
  esac
  printf 'npx'
}

trim() {
  printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

has_make_target() {
  local target="$1"
  [ -f "$ROOT/Makefile" ] && grep -Eq "^${target}:" "$ROOT/Makefile"
}

has_just_target() {
  local target="$1"
  [ -f "$ROOT/justfile" ] && grep -Eq "^${target}:" "$ROOT/justfile"
}

pkg_has_script() {
  local name="$1"
  [ -f "$ROOT/package.json" ] || return 1
  python3 - <<PY >/dev/null 2>&1
import json, sys
with open("$ROOT/package.json", "r", encoding="utf-8") as f:
    data = json.load(f)
scripts = data.get("scripts", {})
sys.exit(0 if "$name" in scripts else 1)
PY
}

pkg_has_dep() {
  local pattern="$1"
  [ -f "$ROOT/package.json" ] || return 1
  grep -Eq "$pattern" "$ROOT/package.json"
}

pkg_script_cmd() {
  local name="$1"
  if pkg_has_script "$name"; then
    printf '%s %s\n' "$(pkg_runner_value)" "$name"
    return 0
  fi
  return 1
}

TEST_CMD=""
LINT_CMD=""
BUILD_CMD=""
DEV_CMD=""

if has_make_target test; then TEST_CMD="make test"; fi
if has_make_target lint; then LINT_CMD="make lint"; fi
if has_make_target build; then BUILD_CMD="make build"; fi
if has_make_target dev; then DEV_CMD="make dev"; fi

if [ -z "$TEST_CMD" ] && has_just_target test; then TEST_CMD="just test"; fi
if [ -z "$LINT_CMD" ] && has_just_target lint; then LINT_CMD="just lint"; fi
if [ -z "$BUILD_CMD" ] && has_just_target build; then BUILD_CMD="just build"; fi
if [ -z "$DEV_CMD" ] && has_just_target dev; then DEV_CMD="just dev"; fi

if [ -f "$ROOT/package.json" ]; then
  [ -z "$TEST_CMD" ] && TEST_CMD="$(pkg_script_cmd test || true)"
  [ -z "$LINT_CMD" ] && LINT_CMD="$(pkg_script_cmd lint || pkg_script_cmd check || true)"
  [ -z "$BUILD_CMD" ] && BUILD_CMD="$(pkg_script_cmd build || true)"
  [ -z "$DEV_CMD" ] && DEV_CMD="$(pkg_script_cmd dev || pkg_script_cmd start || true)"
  if [ -z "$DEV_CMD" ] && pkg_has_dep '"expo"'; then
    DEV_CMD="$(pkg_exec_value) expo start"
  fi
  if [ -z "$DEV_CMD" ] && pkg_has_dep '"react-native"'; then
    DEV_CMD="$(pkg_exec_value) react-native start"
  fi
fi

if [ -f "$ROOT/pubspec.yaml" ]; then
  [ -z "$TEST_CMD" ] && TEST_CMD="flutter test"
  [ -z "$LINT_CMD" ] && LINT_CMD="flutter analyze"
  [ -z "$DEV_CMD" ] && DEV_CMD="flutter run"
  if [ -z "$BUILD_CMD" ]; then
    if find "$ROOT" -maxdepth 2 -type d -name android | grep -q .; then
      BUILD_CMD="flutter build apk"
    elif find "$ROOT" -maxdepth 2 -type d -name ios | grep -q .; then
      BUILD_CMD="flutter build ios --no-codesign"
    fi
  fi
fi

if [ -f "$ROOT/pyproject.toml" ] || [ -f "$ROOT/requirements.txt" ]; then
  [ -z "$TEST_CMD" ] && TEST_CMD="pytest"
  [ -z "$LINT_CMD" ] && LINT_CMD="ruff check . && ruff format --check ."
fi

if [ -f "$ROOT/Cargo.toml" ]; then
  [ -z "$TEST_CMD" ] && TEST_CMD="cargo test"
  [ -z "$LINT_CMD" ] && LINT_CMD="cargo fmt --check && cargo clippy --all-targets --all-features -- -D warnings"
  [ -z "$BUILD_CMD" ] && BUILD_CMD="cargo build"
  [ -z "$DEV_CMD" ] && DEV_CMD="cargo run"
fi

if find "$ROOT" -maxdepth 1 \( -name '*.csproj' -o -name '*.sln' \) | grep -q .; then
  [ -z "$TEST_CMD" ] && TEST_CMD="dotnet test"
  [ -z "$LINT_CMD" ] && LINT_CMD="dotnet format --verify-no-changes"
  [ -z "$BUILD_CMD" ] && BUILD_CMD="dotnet build"
  [ -z "$DEV_CMD" ] && DEV_CMD="dotnet run"
fi

if [ -f "$ROOT/go.mod" ]; then
  [ -z "$TEST_CMD" ] && TEST_CMD="go test ./..."
  [ -z "$BUILD_CMD" ] && BUILD_CMD="go build ./..."
fi

printf '# Project-local command registry for the AI Codex Framework.\n'
printf '# This file is auto-generated on bootstrap from repo detection.\n'
printf '# Set PROJECT_COMMANDS_MODE=\"manual\" to opt out of auto-refresh.\n\n'
printf 'PROJECT_COMMANDS_MODE="auto"\n'
printf 'PACKAGE_RUNNER="%s"\n' "$(pkg_runner_value)"
printf 'PACKAGE_EXEC="%s"\n' "$(pkg_exec_value)"
printf 'TEST_CMD="%s"\n' "$(trim "$TEST_CMD")"
printf 'LINT_CMD="%s"\n' "$(trim "$LINT_CMD")"
printf 'BUILD_CMD="%s"\n' "$(trim "$BUILD_CMD")"
printf 'DEV_CMD="%s"\n' "$(trim "$DEV_CMD")"
