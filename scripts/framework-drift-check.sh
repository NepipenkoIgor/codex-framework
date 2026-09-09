#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
failures=0

fail() {
  printf 'drift: %s\n' "$1"
  failures=$((failures + 1))
}

for path in \
  CODEX.md CODEX.capabilities.md CODEX.concepts.md CODEX.permissions.md CODEX.skills.md CODEX.versions.md CONCEPTS.md ORCHESTRATOR_REFERENCE.md routing.yaml agents .codex-memory \
  scripts/codex-fw.sh scripts/lib/routing-skills.sh scripts/agent-registry.sh scripts/framework-maturity.sh scripts/framework-benchmark.sh scripts/browser-verify.sh \
  scripts/work.sh scripts/issue-worktrees.sh scripts/extract-spec.sh scripts/github-issue-fetch.sh scripts/github-pr-context.sh scripts/github-review-prep.sh scripts/github-status.sh scripts/context-pack.sh scripts/memory-state.sh scripts/hooks/session-start.sh \
  scripts/pr-body.sh scripts/pr-create.sh scripts/pr-publish.sh scripts/pr-ready.sh scripts/safe-commit.sh scripts/preflight.sh scripts/doctor.sh; do
  [ ! -e "$ROOT/$path" ] || fail "obsolete abstraction remains: $path"
done

for path in "$ROOT"/.codex/agents/*.toml; do
  [ -f "$path" ] || fail 'no native agent profiles found'
  grep -q '^name = ' "$path" || fail "agent lacks name: ${path#"$ROOT"/}"
  grep -q '^description = ' "$path" || fail "agent lacks description: ${path#"$ROOT"/}"
  grep -q '^developer_instructions = ' "$path" || fail "agent lacks instructions: ${path#"$ROOT"/}"
done

grep -q '^max_concurrent_threads_per_session = 4$' "$ROOT/.codex/config.toml" || fail 'native agent thread cap is missing'
grep -Eq '^max_depth[[:space:]]*=' "$ROOT/.codex/config.toml" && fail 'obsolete custom agent depth override remains'
grep -q '^## Visible orchestration$' "$ROOT/AGENTS.md" || fail 'visible orchestration contract is missing'
grep -q 'start a native goal immediately and continue until done' "$ROOT/AGENTS.md" || fail 'native goal persistence requirement is missing'
grep -q 'Announce a subagent only after spawning it' "$ROOT/AGENTS.md" || fail 'real agent status requirement is missing'
grep -q 'profile — model / effort — bounded responsibility' "$ROOT/AGENTS.md" || fail 'agent model visibility requirement is missing'
grep -q 'Skills are workflows, not agents' "$ROOT/AGENTS.md" || fail 'skill and agent distinction is missing'
grep -q 'Never manufacture plan files' "$ROOT/AGENTS.md" || fail 'synthetic orchestration guard is missing'
grep -q '^## Native capability currency$' "$ROOT/AGENTS.md" || fail 'native capability currency contract is missing'
grep -q 'native-capability-ledger.json' "$ROOT/AGENTS.md" || fail 'native capability ledger is not required by framework guidance'
grep -Eqi 'apply the safe cleanup in the same (framework )?task' "$ROOT/AGENTS.md" || fail 'native overlap cleanup is not mandatory'
grep -q 'Daybreak Blue never implies Daybreak Red authorization' "$ROOT/AGENTS.md" || fail 'native cyber-access approval boundary is missing'
grep -q '^## Agent profiles and review$' "$ROOT/AGENTS.md" || fail 'falsification-review contract is missing'
grep -q 'exactly one independent read-only falsification pass' "$ROOT/AGENTS.md" || fail 'falsification-review loop is not hard-bounded'
grep -q 'no inherited conversation turns or prior-agent history' "$ROOT/AGENTS.md" || fail 'falsification reviewer does not require fresh context'
grep -q 'only a neutral evidence bundle' "$ROOT/AGENTS.md" || fail 'falsification reviewer evidence bundle is not neutral and bounded'
grep -q 'cannot prove the no-history boundary' "$ROOT/AGENTS.md" || fail 'falsification reviewer does not fail closed when context independence is unavailable'
grep -q 'at most one revision cycle unless the user requests a deeper audit' "$ROOT/AGENTS.md" || fail 'additional review lacks an explicit user gate'
grep -q 'fresh context with no prior conversation or agent history' "$ROOT/.codex/agents/reviewer.toml" || fail 'reviewer profile does not enforce fresh-context review'
grep -q 'report the independence contract as invalid instead of certifying' "$ROOT/.codex/agents/reviewer.toml" || fail 'reviewer profile can certify a biased evidence bundle'
python3 "$ROOT/scripts/framework-review-context-check.py" || fail 'fresh-context review semantics are missing or contradictory'
for instructions in "$ROOT/templates/global/AGENTS.md"; do
  grep -q 'no inherited conversation turns or prior-agent history' "$instructions" || fail "fresh-context reviewer policy is missing: ${instructions#"$ROOT"/}"
  grep -Eqi 'repository-native development server.*early|start or attach.*repository-native development server' "$instructions" || fail "interactive dev server contract is missing: ${instructions#"$ROOT"/}"
  grep -Eqi 'visible.*in-app Browser|in-app Browser.*visible' "$instructions" || fail "visible in-app Browser default is missing: ${instructions#"$ROOT"/}"
  grep -Eqi 'reuse.*Browser binding|reuse the browser binding' "$instructions" || fail "Browser tab recovery contract is missing: ${instructions#"$ROOT"/}"
  grep -Eqi 'headless.*supplement|headless E2E.*supplement' "$instructions" || fail "headless supplementary-only boundary is missing: ${instructions#"$ROOT"/}"
  grep -Eqi 'task-owned.*(tab|process|resource)' "$instructions" || fail "task-owned interactive cleanup is missing: ${instructions#"$ROOT"/}"
  grep -Eqi 'visible repository-configured simulator, emulator, or device' "$instructions" || fail "visible mobile target default is missing: ${instructions#"$ROOT"/}"
  grep -Eqi 'Scheduled tasks/automations' "$instructions" && grep -Eqi 'recurring execution.*,? monitoring|monitoring.*,? reminders' "$instructions" || fail "native scheduled automation policy is missing: ${instructions#"$ROOT"/}"
  grep -Eqi 'task names.*,? pins.*,? sections.*,? handoff.*,? forks' "$instructions" || fail "native long-task ergonomics policy is missing: ${instructions#"$ROOT"/}"
  python3 "$ROOT/scripts/framework-task-topology-check.py" "$instructions" || fail "native task topology semantics are missing or contradictory: ${instructions#"$ROOT"/}"
  grep -Eqi 'Record & Replay.*user-demonstrated|Record & Replay.*demonstrated.*workflow' "$instructions" || fail "Record and Replay user-gate policy is missing: ${instructions#"$ROOT"/}"
done
test -s "$ROOT/docs/interactive-development.md" || fail 'interactive development lifecycle documentation is missing'
test -s "$ROOT/docs/native-capability-review.md" || fail 'native capability review documentation is missing'
test -s "$ROOT/docs/native-capability-ledger.json" || fail 'native capability ledger is missing'
test -s "$ROOT/docs/native-capability-ledger.schema.json" || fail 'native capability ledger schema is missing'
python3 "$ROOT/scripts/framework-native-capability-check.py" || fail 'native capability ledger is stale or inconsistent'
python3 "$ROOT/scripts/framework-native-capability-check.py" --self-test || fail 'native capability checker counterexamples are not rejected'
grep -q 'Act as an independent falsifier' "$ROOT/.codex/agents/reviewer.toml" || fail 'reviewer is not instructed to falsify'
grep -q 'Every actionable finding must include severity, concrete evidence' "$ROOT/.codex/agents/reviewer.toml" || fail 'reviewer evidence contract is missing'
grep -q '^sandbox_mode = "read-only"$' "$ROOT/.codex/agents/reviewer.toml" || fail 'reviewer is not read-only'
grep -q 'Do not edit files, recursively delegate' "$ROOT/.codex/agents/reviewer.toml" || fail 'reviewer edit/delegation guard is missing'
grep -q '^model_reasoning_effort = "high"$' "$ROOT/.codex/agents/architect.toml" || fail 'architect reasoning override is missing'
grep -q '^model_reasoning_effort = "high"$' "$ROOT/.codex/agents/reviewer.toml" || fail 'reviewer reasoning override is missing'
grep -q '^model_reasoning_effort = ' "$ROOT/.codex/agents/tester.toml" && fail 'tester should inherit native model effort selection'
test -s "$ROOT/templates/global/AGENTS.md" || fail 'global guidance template is missing'
grep -q 'Prefer native Codex capabilities' "$ROOT/templates/global/AGENTS.md" || fail 'global native-capability guidance is missing'
test ! -e "$ROOT/.codex/agents/explorer.toml" || fail 'custom explorer shadows the built-in agent'
test ! -e "$ROOT/.codex/agents/builder.toml" || fail 'custom builder duplicates the built-in worker'
test ! -e "$ROOT/plugins/ai-codex-framework" || fail 'legacy duplicate hooks plugin remains'
test -s "$ROOT/.agents/plugins/marketplace.json" || fail 'repo plugin marketplace is missing'
test -s "$ROOT/plugins/codex-frontend-design/.codex-plugin/plugin.json" || fail 'frontend-design plugin pilot is missing'
test -s "$ROOT/.codex/rules/safety.rules" || fail 'native safety rules are missing'
if grep -Eq '/Users/|/home/' "$ROOT/.codex/config.toml"; then
  fail 'machine-specific path remains in project config'
fi
if grep -Eq 'routing-skills|codex-fw|model_retry_chain|runtime_type|spawn_agent\.agent_type' "$ROOT"/AGENTS.md "$ROOT"/README.md "$ROOT"/scripts/hooks.sh "$ROOT"/scripts/hooks/*.sh "$ROOT"/scripts/lib.sh; then
  fail 'legacy orchestration language remains in runtime surface'
fi
if grep -Eq '^\[\[hooks\.(SessionStart|UserPromptSubmit|PostToolUse|Stop)\]\]' "$ROOT/.codex/config.toml"; then
  fail 'context-injection or prompt-routing hook remains in native config'
fi

bash "$ROOT/scripts/hooks.sh" doctor "$ROOT" || fail 'hook configuration is invalid'
bash "$ROOT/scripts/hooks.sh" smoke "$ROOT" || fail 'hook smoke failed'

[ "$failures" -eq 0 ] || exit 1
printf 'framework drift check passed\n'
