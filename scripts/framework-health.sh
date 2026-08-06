#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
failures=0

for file in AGENTS.md README.md .codex/config.toml .codex/skill-packs.txt docs/framework-release-evidence.schema.json plugins/ai-codex-framework/.codex-plugin/plugin.json plugins/ai-codex-framework/hooks/hooks.json .codex/rules/safety.rules scripts/setup.sh scripts/bootstrap-project.sh scripts/hooks.sh scripts/framework-install.py scripts/framework-link-install.py scripts/framework-doctor.sh scripts/framework-doctor-native.py scripts/framework-doctor-self-test.sh scripts/framework-skill-sync.sh scripts/framework-skill-loader-live-eval.sh scripts/framework-release-evidence.py scripts/framework-release.sh scripts/framework-eval.sh scripts/framework-drift-check.sh scripts/framework-version-drift-check.sh scripts/framework-stack-context.py scripts/surface-parity-check.sh scripts/framework-skill-governance.sh scripts/framework-skill-quality.py scripts/framework-skill-contract-scaffold.py skills/version-sources.tsv; do
  [ -f "$ROOT/$file" ] || { printf 'missing: %s\n' "$file"; failures=$((failures + 1)); }
done

[ -n "$(find "$ROOT/skills" -name SKILL.md -print -quit)" ] || { printf 'no skills found\n'; failures=$((failures + 1)); }
bash "$ROOT/scripts/framework-eval.sh" || failures=$((failures + 1))
bash "$ROOT/scripts/framework-drift-check.sh" || failures=$((failures + 1))
bash "$ROOT/scripts/surface-parity-check.sh" || failures=$((failures + 1))

printf 'framework health: %d failures\n' "$failures"
[ "$failures" -eq 0 ]
