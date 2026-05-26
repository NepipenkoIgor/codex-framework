#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/scripts/lib.sh"
failures=0

has_rg=false
if command -v rg >/dev/null 2>&1; then
  has_rg=true
fi

contains_pattern() {
  local pattern="$1"
  local file="$2"
  if [ "$has_rg" = true ]; then
    rg -q "$pattern" "$file"
  else
    grep -Eq "$pattern" "$file"
  fi
}

tree_contains_pattern() {
  local pattern="$1"
  local path="$2"
  if [ "$has_rg" = true ]; then
    rg -n "$pattern" "$path" -g 'SKILL.md' >/dev/null 2>&1
  else
    grep -ERn --include='SKILL.md' "$pattern" "$path" >/dev/null 2>&1
  fi
}

check_model_consistency() {
  local tier="$1"
  local expected_model expected_reasoning model_pattern reasoning_pattern
  expected_model="$(tier_model "$tier")"
  expected_reasoning="$(tier_reasoning "$tier")"
  model_pattern="model: ${expected_model}"
  reasoning_pattern="reasoning: ${expected_reasoning}"
  if ! contains_pattern "^  ${tier}:$" "$ROOT/routing.yaml" || ! contains_pattern "$model_pattern" "$ROOT/routing.yaml" || ! contains_pattern "$reasoning_pattern" "$ROOT/routing.yaml"; then
    echo "routing mismatch: ${tier} should map to model=${expected_model} reasoning=${expected_reasoning}"
    failures=$((failures + 1))
  fi
}

check_route_expectation() {
  local task="$1"
  local expected="$2"
  local actual
  actual="$(bash "$ROOT/scripts/codex-fw.sh" route "$task")"
  if ! printf '%s\n' "$actual" | grep -Eq "$expected"; then
    echo "route mismatch: task [$task] did not match expectation [$expected]"
    echo "  actual: $actual"
    failures=$((failures + 1))
  fi
}

check_file() {
  if [ ! -f "$ROOT/$1" ]; then
    echo "missing: $1"
    failures=$((failures + 1))
  fi
}

check_file "README.md"
check_file "CODEX.md"
check_file "CODEX.concepts.md"
check_file "CODEX.skills.md"
check_file "CODEX.versions.md"
check_file "CODEX.capabilities.md"
check_file "CODEX.permissions.md"
check_file "ORCHESTRATOR_REFERENCE.md"
check_file "CONCEPTS.md"
check_file "routing.yaml"
check_file "SKILLS_MAP.core.md"
check_file "SKILLS_MAP.frontend.md"
check_file "SKILLS_MAP.backend.md"
check_file "SKILLS_MAP.mobile.md"
check_file "SKILLS_MAP.infra.md"
check_file "SKILLS_MAP.specialized.md"
check_file "SKILLS_MAP.testing.md"
check_file "scripts/setup.sh"
check_file "scripts/framework-eval.sh"
check_file "scripts/framework-maturity.sh"
check_file "scripts/framework-drift-check.sh"
check_file "scripts/framework-benchmark.sh"
check_file "scripts/framework-skill-quality.sh"
check_file "scripts/framework-skill-corpus-audit.sh"
check_file "scripts/detect-project-stack.sh"
check_file "scripts/detect-project-features.sh"
check_file "scripts/detect-project-policy.sh"
check_file "scripts/detect-project-conventions.sh"
check_file "scripts/detect-repo-intelligence.sh"
check_file "scripts/detect-project-commands.sh"
check_file "scripts/capabilities.sh"
check_file "scripts/doctor.sh"
check_file "scripts/context-pack.sh"
check_file "scripts/hooks.sh"
check_file "scripts/hooks/lib.sh"
check_file "scripts/hooks/session-start.sh"
check_file "scripts/hooks/user-prompt-submit.sh"
check_file "scripts/hooks/pre-tool-use.sh"
check_file "scripts/hooks/post-tool-use.sh"
check_file "scripts/hooks/stop.sh"
check_file "scripts/agent-registry.sh"
check_file "scripts/guard-scan.sh"
check_file "scripts/quality-check.sh"
check_file "scripts/pre-commit-check.sh"
check_file "scripts/commit-msg-check.sh"
	check_file "scripts/handoff-state.sh"
	check_file "scripts/memory-state.sh"
	check_file "scripts/memory-contract-check.sh"
	check_file "scripts/retry-state.sh"
check_file "scripts/banner.sh"
check_file "scripts/plan.sh"
check_file "scripts/session-start.sh"
check_file "scripts/status-block.sh"
check_file "scripts/github-status.sh"
check_file "scripts/github-issue-fetch.sh"
check_file "scripts/github-pr-context.sh"
check_file "scripts/github-review-prep.sh"
check_file "scripts/task-brief.sh"
check_file "scripts/lib.sh"
check_file "scripts/lib/git-flow.sh"
check_file "scripts/lib/repo-detection.sh"
check_file "scripts/lib/routing-skills.sh"
check_file "scripts/preflight.sh"
check_file "scripts/post-change-check.sh"
check_file "scripts/spec-status.sh"
check_file "scripts/extract-spec.sh"
check_file "scripts/work.sh"
check_file "scripts/pr-ready.sh"
check_file "scripts/pr-publish.sh"
check_file "scripts/pr-body.sh"
check_file "scripts/pr-create.sh"
check_file "scripts/safe-commit.sh"
check_file "scripts/browser-verify.sh"
check_file "scripts/codex-fw.sh"
check_file "templates/project/CODEX.md"
check_file "templates/project/.codex/project.env"
check_file "agents/registry.tsv"
check_file "agents/builder-mobile.md"
check_file "agents/builder-fullstack.md"
check_file "agents/builder-automation.md"
check_file "agents/builder-ai.md"
check_file "agents/builder-n8n.md"
check_file "skills/framework-orchestration-audit/SKILL.md"

skill_count=$(find "$ROOT/skills" -name SKILL.md | wc -l | tr -d ' ')
agent_count=$(find "$ROOT/agents" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')

if [ "$skill_count" -eq 0 ]; then
  echo "no skills found"
  failures=$((failures + 1))
fi

if [ "$agent_count" -eq 0 ]; then
  echo "no agents found"
  failures=$((failures + 1))
fi

while IFS= read -r file; do
  if ! contains_pattern '^---$' "$file"; then
    echo "no frontmatter fence: ${file#$ROOT/}"
    failures=$((failures + 1))
  fi
done < <(find "$ROOT/skills" -name SKILL.md)

while IFS= read -r file; do
  if ! contains_pattern '^# ' "$file"; then
    echo "missing top heading: ${file#$ROOT/}"
    failures=$((failures + 1))
  fi
done < <(find "$ROOT/agents" -maxdepth 1 -name '*.md')

while IFS= read -r file; do
  if [ ! -x "$file" ]; then
    echo "script not executable: ${file#$ROOT/}"
    failures=$((failures + 1))
  fi
done < <(find "$ROOT/scripts" -maxdepth 1 -name '*.sh')

while IFS= read -r file; do
  if [ ! -x "$file" ]; then
    echo "hook script not executable: ${file#$ROOT/}"
    failures=$((failures + 1))
  fi
done < <(find "$ROOT/scripts/hooks" -maxdepth 1 -name '*.sh')

if tree_contains_pattern "CLAUDE\.md|\.claude/|enabledPlugins|teammateMode" "$ROOT/skills"; then
  echo "framework drift: Claude-specific references found in skills/"
  failures=$((failures + 1))
fi

if tree_contains_pattern "CLAUDE\.md|\.claude/|enabledPlugins|teammateMode" "$ROOT/agents"; then
  echo "framework drift: Claude-specific references found in agents/"
  failures=$((failures + 1))
fi

if tree_contains_pattern "Claude Code|pm~[a-z]|fix~[a-z]|surfaces failures back to Claude|leaving Claude Code" "$ROOT/skills"; then
  echo "framework drift: Claude-era user-facing workflow references found in skills/"
  failures=$((failures + 1))
fi

if tree_contains_pattern "claude-sonnet|claude-haiku|anthropic\(" "$ROOT/skills"; then
  echo "framework drift: provider-specific Claude model references found in skills/"
  failures=$((failures + 1))
fi

if contains_pattern "gpt-5\.2-codex" "$ROOT/scripts/codex-fw.sh" || contains_pattern "gpt-5\.2-codex" "$ROOT/scripts/plan.sh" || contains_pattern "gpt-5\.2-codex" "$ROOT/routing.yaml"; then
  echo "routing mismatch: stale gpt-5.2-codex references found in core routing files"
  failures=$((failures + 1))
fi

check_model_consistency "low"
check_model_consistency "medium"
check_model_consistency "high"
check_model_consistency "xhigh"

check_route_expectation "review GitHub PR #123 and check CI" 'role=reviewer .*tier=medium .*model=gpt-5\.5'
check_route_expectation "fix checkout race condition across API and webhook handling" 'role=fixer .*tier=high .*model=gpt-5\.5'
check_route_expectation "create small config rename in single-file script" 'role=builder .*tier=low .*model=gpt-5\.4-mini'
check_route_expectation "create PR with release summary" 'role=project-manager .*tier=low .*model=gpt-5\.4-mini'
check_route_expectation "estimate scope and cost for checkout migration" 'role=estimator .*tier=medium .*model=gpt-5\.5'
check_route_expectation "design API contract for new billing service" 'role=architect .*tier=high .*model=gpt-5\.5'
check_route_expectation "update API schema for billing webhooks" 'role=(architect|builder-backend|fixer) .*tier=high .*model=gpt-5\.5'
check_route_expectation "analyze framework orchestration and human-like engineer agents with domain knowledge" 'role=framework-manager .*tier=xhigh .*model=gpt-5\.5'
check_route_expectation "проанализируй оркестрацию фреймворка и агентов с доменными знаниями" 'role=framework-manager .*tier=xhigh .*model=gpt-5\.5'
check_route_expectation "проверь статус нашего фреймворка что хорошо что плохо что легаси и грязь нужно удалить что мешает эффективно выжимать из codex больше чем просто промпт кодинг" 'role=framework-manager .*tier=xhigh .*model=gpt-5\.5'
check_route_expectation "уберем легаси и используем codex hooks как основной runtime" 'role=framework-manager .*tier=xhigh .*model=gpt-5\.5'

if ! bash "$ROOT/scripts/framework-eval.sh" >/dev/null 2>&1; then
  echo "framework eval failed"
  failures=$((failures + 1))
fi

if ! bash "$ROOT/scripts/framework-maturity.sh" >/dev/null 2>&1; then
  echo "framework maturity check failed"
  failures=$((failures + 1))
fi

if ! bash "$ROOT/scripts/framework-drift-check.sh" >/dev/null 2>&1; then
  echo "framework drift check failed"
  failures=$((failures + 1))
fi

if ! bash "$ROOT/scripts/memory-contract-check.sh" >/dev/null 2>&1; then
  echo "memory contract check failed"
  failures=$((failures + 1))
fi

if ! bash "$ROOT/scripts/framework-benchmark.sh" >/dev/null 2>&1; then
  echo "framework benchmark failed"
  failures=$((failures + 1))
fi

if ! bash "$ROOT/scripts/framework-skill-quality.sh" >/dev/null 2>&1; then
  echo "framework skill quality audit failed"
  failures=$((failures + 1))
fi

if ! bash "$ROOT/scripts/framework-skill-corpus-audit.sh" >/dev/null 2>&1; then
  echo "framework skill corpus audit failed"
  failures=$((failures + 1))
fi

if ! bash "$ROOT/scripts/guard-scan.sh" --all >/dev/null 2>&1; then
  echo "framework corpus guard scan failed"
  failures=$((failures + 1))
fi

if ! bash "$ROOT/scripts/detect-project-commands.sh" "$ROOT" >/dev/null 2>&1; then
  echo "command detection failed"
  failures=$((failures + 1))
fi

if ! bash "$ROOT/scripts/doctor.sh" "$ROOT" >/dev/null 2>&1; then
  echo "doctor failed"
  failures=$((failures + 1))
fi

if ! bash "$ROOT/scripts/hooks.sh" smoke "$ROOT" >/dev/null 2>&1; then
  echo "hook smoke failed"
  failures=$((failures + 1))
fi

if ! bash "$ROOT/scripts/agent-registry.sh" validate >/dev/null 2>&1; then
  echo "agent registry validation failed"
  failures=$((failures + 1))
fi

echo "agents=$agent_count skills=$skill_count"

if [ "$failures" -ne 0 ]; then
  exit 1
fi
