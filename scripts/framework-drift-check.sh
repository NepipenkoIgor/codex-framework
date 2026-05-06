#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/scripts/lib.sh"

failures=0

fail_check() {
  printf 'drift: %s\n' "$1"
  failures=$((failures + 1))
}

roles_from_routing() {
  awk '
    $1 == "roles:" { in_roles=1; next }
    in_roles && $1 == "verification:" { in_roles=0 }
    in_roles && $0 ~ /^  [a-z0-9-]+:$/ { gsub(":", "", $1); print $1 }
  ' "$ROOT/routing.yaml"
}

skills_from_routing() {
  awk '
    $1 == "skills:" { in_skills=1; next }
    in_skills && $1 == "-" { print $2; next }
    in_skills && $1 != "-" { in_skills=0 }
  ' "$ROOT/routing.yaml" | sort -u
}

check_model_tier() {
  local tier="$1"
  local expected_model expected_reasoning
  expected_model="$(tier_model "$tier")"
  expected_reasoning="$(tier_reasoning "$tier")"
  grep -Eq "^  ${tier}:$" "$ROOT/routing.yaml" || fail_check "routing.yaml missing model tier $tier"
  grep -Eq "model: ${expected_model}" "$ROOT/routing.yaml" || fail_check "routing.yaml model mismatch for $tier"
  grep -Eq "reasoning: ${expected_reasoning}" "$ROOT/routing.yaml" || fail_check "routing.yaml reasoning mismatch for $tier"
}

check_route_probe() {
  local role="$1"
  local probe="$2"
  local actual
  actual="$(bash "$ROOT/scripts/codex-fw.sh" route "$probe")"
  if ! printf '%s\n' "$actual" | grep -Eq "role=${role}( |$)"; then
    fail_check "role $role is not reached by probe [$probe]; actual: $actual"
  fi
}

while IFS= read -r role; do
  [ -n "$role" ] || continue
  [ -f "$ROOT/agents/$role.md" ] || fail_check "routing role has no role brief: $role"
done < <(roles_from_routing)

while IFS= read -r skill; do
  [ -n "$skill" ] || continue
  [ -f "$ROOT/skills/$skill/SKILL.md" ] || fail_check "routing skill has no SKILL.md: $skill"
done < <(skills_from_routing)

check_model_tier low
check_model_tier medium
check_model_tier high
check_model_tier xhigh

check_route_probe architect "design API contract for billing"
check_route_probe builder "implement feature"
check_route_probe builder-frontend "build UI component"
check_route_probe builder-backend "implement backend endpoint"
check_route_probe builder-infra "deploy Kubernetes workload"
check_route_probe builder-mobile "implement React Native screen"
check_route_probe builder-fullstack "nextjs app router page and api"
check_route_probe builder-automation "build automation workflow"
check_route_probe builder-ai "build RAG chatbot"
check_route_probe builder-n8n "build n8n webhook chain"
check_route_probe fixer "fix crash in service"
check_route_probe refactorer "refactor duplicated logic"
check_route_probe reviewer "review GitHub PR"
check_route_probe tester "write regression tests"
check_route_probe project-manager "create PR with release summary"
check_route_probe estimator "estimate scope and cost"
check_route_probe auditor "dependency audit CVE"
check_route_probe framework-manager "framework orchestration audit"

if ! grep -q 'framework-orchestration-audit' "$ROOT/CODEX.skills.md"; then
  fail_check "CODEX.skills.md does not register framework-orchestration-audit"
fi

if [ -n "$(git -C "$ROOT" ls-files .codex .githooks)" ]; then
  fail_check "runtime state is tracked; remove .codex/.githooks from the index"
fi

for pattern in '/.codex/cache/' '/.codex/runs/' '/.codex/specs/' '/.codex/project.env' '/.githooks/'; do
  if ! grep -qx "$pattern" "$ROOT/.gitignore" 2>/dev/null; then
    fail_check ".gitignore missing runtime-state rule: $pattern"
  fi
done

if ! grep -q -- '--head "$HEAD_BRANCH"' "$ROOT/scripts/pr-create.sh" || ! grep -q -- '--base "$BASE_BRANCH"' "$ROOT/scripts/pr-create.sh"; then
  fail_check "pr-create does not create PRs with explicit base/head"
fi

if ! grep -q 'codex/\*)' "$ROOT/scripts/pr-ready.sh"; then
  fail_check "pr-ready does not reject tool-revealing codex/* branches"
fi

if [ "$failures" -ne 0 ]; then
  printf 'framework drift check: %d failures\n' "$failures"
  exit 1
fi

printf 'framework drift check passed\n'
