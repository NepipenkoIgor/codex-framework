#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCES="$ROOT/skills/version-sources.tsv"
RESOLVER="$ROOT/scripts/framework-stack-context.py"
MODE="${1:-offline}"

[ "$MODE" = offline ] || [ "$MODE" = --live ] || [ "$MODE" = --self-test ] || { printf 'usage: framework-version-drift-check.sh [--live|--self-test]\n' >&2; exit 1; }

python3 "$RESOLVER" --sources "$SOURCES" self-test >/dev/null

# Skills may recommend floating vendor scaffolds, but must not freeze a major in a bootstrap command.
numeric_bootstrap_pattern='create-next-app@[0-9]|create-expo-app.*sdk-[0-9]|(npm[[:space:]]+create[[:space:]]+nuxt|npx[[:space:]]+(nuxi|create-nuxt))@[0-9]|@angular/cli@[0-9]|FROM[[:space:]]+node:[0-9]|FROM[[:space:]]+python:[0-9]|dotnet new.*--framework[[:space:]]+net[0-9]'
if rg -n "$numeric_bootstrap_pattern" \
  "$ROOT/skills" "$ROOT/docs" "$ROOT/README.md" "$ROOT/AGENTS.md" "$ROOT/templates/global/AGENTS.md" \
  -g 'SKILL.md' -g 'references/*.md' -g '*.md'; then
  printf 'numeric version pinned in bootstrap guidance\n' >&2
  exit 1
fi

if [ "$MODE" = --self-test ]; then
  for command in 'npx create-next-app@16 app' 'npx create-expo-app --template default@sdk-57' 'npm create nuxt@4 app' 'FROM node:24-alpine' 'dotnet new webapi --framework net10.0'; do
    printf '%s\n' "$command" | rg -q "$numeric_bootstrap_pattern" || { printf 'self-test missed numeric bootstrap: %s\n' "$command" >&2; exit 1; }
  done
  for command in 'npx create-next-app@latest app' 'npm create nuxt@latest app' 'npx @angular/cli@latest new app'; do
    ! printf '%s\n' "$command" | rg -q "$numeric_bootstrap_pattern" || { printf 'self-test rejected floating bootstrap: %s\n' "$command" >&2; exit 1; }
  done
  python3 "$RESOLVER" --sources "$SOURCES" self-test
  exit 0
fi

if [ "$MODE" = --live ]; then
  python3 "$RESOLVER" --sources "$SOURCES" latest --format markdown
else
  printf 'version source registry: %s dynamic resolvers, structural checks passed\n' "$(tail -n +2 "$SOURCES" | sed '/^$/d' | wc -l | tr -d ' ')"
fi
