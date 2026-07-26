#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
failures=0

for file in AGENTS.md README.md .codex/config.toml plugins/ai-codex-framework/.codex-plugin/plugin.json plugins/ai-codex-framework/hooks/hooks.json .codex/rules/safety.rules scripts/setup.sh scripts/bootstrap-project.sh scripts/hooks.sh scripts/framework-eval.sh scripts/framework-drift-check.sh scripts/surface-parity-check.sh; do
  [ -f "$ROOT/$file" ] || { printf 'missing: %s\n' "$file"; failures=$((failures + 1)); }
done

find "$ROOT/skills" -name SKILL.md | grep -q . || { printf 'no skills found\n'; failures=$((failures + 1)); }
bash "$ROOT/scripts/framework-eval.sh" || failures=$((failures + 1))
bash "$ROOT/scripts/framework-drift-check.sh" || failures=$((failures + 1))
bash "$ROOT/scripts/surface-parity-check.sh" || failures=$((failures + 1))
bash "$ROOT/scripts/framework-skill-corpus-audit.sh" >/dev/null || failures=$((failures + 1))

printf 'framework health: %d failures\n' "$failures"
[ "$failures" -eq 0 ]
