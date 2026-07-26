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
  scripts/work.sh scripts/issue-worktrees.sh scripts/extract-spec.sh scripts/github-issue-fetch.sh scripts/github-pr-context.sh scripts/github-review-prep.sh scripts/github-status.sh scripts/context-pack.sh scripts/memory-state.sh scripts/hooks/session-start.sh \
  scripts/pr-body.sh scripts/pr-create.sh scripts/pr-publish.sh scripts/pr-ready.sh scripts/safe-commit.sh scripts/preflight.sh scripts/doctor.sh; do
  [ ! -e "$ROOT/$path" ] || fail "obsolete abstraction remains: $path"
done

for path in "$ROOT"/.codex/agents/*.toml; do
  [ -f "$path" ] || fail 'no native agent profiles found'
  grep -q '^name = ' "$path" || fail "agent lacks name: ${path#$ROOT/}"
  grep -q '^description = ' "$path" || fail "agent lacks description: ${path#$ROOT/}"
  grep -q '^developer_instructions = ' "$path" || fail "agent lacks instructions: ${path#$ROOT/}"
done

grep -q '^max_concurrent_threads_per_session = 4$' "$ROOT/.codex/config.toml" || fail 'native agent thread cap is missing'
grep -q '^max_depth = 1$' "$ROOT/.codex/config.toml" || fail 'native agent depth is not bounded'
grep -q '^## Visible orchestration$' "$ROOT/AGENTS.md" || fail 'visible orchestration contract is missing'
grep -q 'create and maintain a native plan before substantive tool work' "$ROOT/AGENTS.md" || fail 'native planning requirement is missing'
grep -q 'Announce a sub-agent only after it has actually been spawned' "$ROOT/AGENTS.md" || fail 'real agent status requirement is missing'
grep -q 'profile — model / effort — bounded responsibility' "$ROOT/AGENTS.md" || fail 'agent model visibility requirement is missing'
grep -q 'Skills do not have a model' "$ROOT/AGENTS.md" || fail 'skill and agent distinction is missing'
grep -q 'Do not manufacture plan files' "$ROOT/AGENTS.md" || fail 'synthetic orchestration guard is missing'
grep -q '^## Falsification review$' "$ROOT/AGENTS.md" || fail 'falsification-review contract is missing'
grep -q 'Stop after exactly one reviewer-to-revision cycle' "$ROOT/AGENTS.md" || fail 'falsification-review loop is not hard-bounded'
grep -q 'A further reviewer pass requires a new explicit user request' "$ROOT/AGENTS.md" || fail 'additional review lacks an explicit user gate'
grep -q 'Skip this review for routine, localized, low-risk changes' "$ROOT/AGENTS.md" || fail 'falsification-review risk gate is missing'
grep -q 'Act as an independent falsifier' "$ROOT/.codex/agents/reviewer.toml" || fail 'reviewer is not instructed to falsify'
grep -q 'Every actionable finding must include severity, concrete evidence' "$ROOT/.codex/agents/reviewer.toml" || fail 'reviewer evidence contract is missing'
grep -q '^sandbox_mode = "read-only"$' "$ROOT/.codex/agents/reviewer.toml" || fail 'reviewer is not read-only'
grep -q 'Do not edit files, recursively delegate' "$ROOT/.codex/agents/reviewer.toml" || fail 'reviewer edit/delegation guard is missing'
test -s "$ROOT/templates/global/AGENTS.md" || fail 'global guidance template is missing'
grep -q 'Prefer native Codex capabilities' "$ROOT/templates/global/AGENTS.md" || fail 'global native-capability guidance is missing'
test ! -e "$ROOT/.codex/agents/explorer.toml" || fail 'custom explorer shadows the built-in agent'
test ! -e "$ROOT/.codex/agents/builder.toml" || fail 'custom builder duplicates the built-in worker'
test -s "$ROOT/plugins/ai-codex-framework/.codex-plugin/plugin.json" || fail 'plugin manifest is missing'
test -s "$ROOT/plugins/ai-codex-framework/hooks/hooks.json" || fail 'plugin hook bundle is missing'
cmp -s "$ROOT/scripts/hooks/pre-tool-use.sh" "$ROOT/plugins/ai-codex-framework/scripts/pre-tool-use.sh" || fail 'plugin pre-tool hook drifted from runtime hook'
cmp -s "$ROOT/scripts/hooks/stop.sh" "$ROOT/plugins/ai-codex-framework/scripts/stop.sh" || fail 'plugin stop hook drifted from runtime hook'
test -s "$ROOT/.codex/rules/safety.rules" || fail 'native safety rules are missing'
if grep -Eq '/Users/|/home/' "$ROOT/.codex/config.toml"; then
  fail 'machine-specific path remains in project config'
fi
if grep -Eq 'routing-skills|codex-fw|model_retry_chain|runtime_type|spawn_agent\.agent_type' "$ROOT"/AGENTS.md "$ROOT"/README.md "$ROOT"/scripts/hooks.sh "$ROOT"/scripts/hooks/*.sh "$ROOT"/scripts/lib.sh; then
  fail 'legacy orchestration language remains in runtime surface'
fi
if grep -Eq '^\[\[hooks\.(SessionStart|UserPromptSubmit|PostToolUse)\]\]' "$ROOT/.codex/config.toml"; then
  fail 'context-injection or prompt-routing hook remains in native config'
fi

bash "$ROOT/scripts/hooks.sh" doctor "$ROOT" || fail 'hook configuration is invalid'
bash "$ROOT/scripts/hooks.sh" smoke "$ROOT" || fail 'hook smoke failed'

[ "$failures" -eq 0 ] || exit 1
printf 'framework drift check passed\n'
