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
check_file "CODEX.skills.md"
check_file "CODEX.capabilities.md"
check_file "CONCEPTS.md"
check_file "routing.yaml"
check_file "scripts/setup.sh"
check_file "scripts/detect-project-stack.sh"
check_file "scripts/detect-project-commands.sh"
check_file "scripts/capabilities.sh"
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
check_file "scripts/preflight.sh"
check_file "scripts/post-change-check.sh"
check_file "scripts/spec-status.sh"
check_file "scripts/extract-spec.sh"
check_file "scripts/work.sh"
check_file "scripts/pr-ready.sh"
check_file "scripts/pr-body.sh"
check_file "scripts/pr-create.sh"
check_file "scripts/safe-commit.sh"
check_file "scripts/browser-verify.sh"
check_file "scripts/codex-fw.sh"
check_file "templates/project/CODEX.md"
check_file "templates/project/.codex/project.env"
check_file "agents/builder-mobile.md"
check_file "agents/builder-fullstack.md"
check_file "agents/builder-automation.md"

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

if tree_contains_pattern "CLAUDE\.md|\.claude/|enabledPlugins|teammateMode" "$ROOT/skills"; then
  echo "framework drift: Claude-specific references found in skills/"
  failures=$((failures + 1))
fi

if tree_contains_pattern "CLAUDE\.md|\.claude/|enabledPlugins|teammateMode" "$ROOT/agents"; then
  echo "framework drift: Claude-specific references found in agents/"
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

check_route_expectation "review GitHub PR #123 and check CI" 'role=reviewer .*tier=medium .*model=gpt-5\.4-mini'
check_route_expectation "fix checkout race condition across API and webhook handling" 'role=fixer .*tier=high .*model=gpt-5\.4'
check_route_expectation "create small config rename in single-file script" 'role=builder .*tier=low .*model=codex-mini-latest'
check_route_expectation "design API contract for new billing service" 'role=architect .*tier=high .*model=gpt-5\.4'

if ! bash "$ROOT/scripts/detect-project-commands.sh" "$ROOT" >/dev/null 2>&1; then
  echo "command detection failed"
  failures=$((failures + 1))
fi

echo "agents=$agent_count skills=$skill_count"

if [ "$failures" -ne 0 ]; then
  exit 1
fi
