#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
failures=0

fail() {
  printf 'drift: %s\n' "$1"
  failures=$((failures + 1))
}

for path in \
  CODEX.md CODEX.capabilities.md CODEX.concepts.md CODEX.permissions.md CODEX.skills.md CODEX.versions.md CONCEPTS.md ORCHESTRATOR_REFERENCE.md routing.yaml agents \
  scripts/codex-fw.sh scripts/lib/routing-skills.sh scripts/agent-registry.sh scripts/framework-maturity.sh scripts/framework-benchmark.sh scripts/browser-verify.sh \
  scripts/work.sh scripts/issue-worktrees.sh scripts/extract-spec.sh scripts/github-issue-fetch.sh scripts/github-pr-context.sh scripts/github-review-prep.sh scripts/github-status.sh \
  scripts/pr-body.sh scripts/pr-create.sh scripts/pr-publish.sh scripts/pr-ready.sh scripts/safe-commit.sh scripts/preflight.sh scripts/doctor.sh; do
  [ ! -e "$ROOT/$path" ] || fail "obsolete abstraction remains: $path"
done

for path in "$ROOT"/.codex/agents/*.toml; do
  [ -f "$path" ] || fail 'no native agent profiles found'
  grep -q '^name = ' "$path" || fail "agent lacks name: ${path#$ROOT/}"
  grep -q '^description = ' "$path" || fail "agent lacks description: ${path#$ROOT/}"
  grep -q '^developer_instructions = ' "$path" || fail "agent lacks instructions: ${path#$ROOT/}"
done

grep -q '^max_threads = 4$' "$ROOT/.codex/config.toml" || fail 'native agent thread cap is missing'
grep -q '^max_depth = 1$' "$ROOT/.codex/config.toml" || fail 'native agent depth is not bounded'
if grep -Eq 'routing-skills|codex-fw|model_retry_chain|runtime_type|spawn_agent\.agent_type' "$ROOT"/AGENTS.md "$ROOT"/README.md "$ROOT"/scripts/hooks.sh "$ROOT"/scripts/hooks/*.sh "$ROOT"/scripts/lib.sh; then
  fail 'legacy orchestration language remains in runtime surface'
fi

bash "$ROOT/scripts/hooks.sh" doctor "$ROOT" || fail 'hook configuration is invalid'
bash "$ROOT/scripts/hooks.sh" smoke "$ROOT" || fail 'hook smoke failed'

[ "$failures" -eq 0 ] || exit 1
printf 'framework drift check passed\n'
