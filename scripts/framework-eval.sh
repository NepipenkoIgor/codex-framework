#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/scripts/lib.sh"

failures=0
total=0
brief_failures=0

check_route() {
  local task="$1"
  local expected="$2"
  local actual
  total=$((total + 1))
  actual="$(bash "$ROOT/scripts/codex-fw.sh" route "$task")"
  if printf '%s\n' "$actual" | grep -Eq "$expected"; then
    printf 'ok %02d route: %s\n' "$total" "$task"
  else
    printf 'not ok %02d route: %s\n' "$total" "$task"
    printf '  expected: %s\n' "$expected"
    printf '  actual:   %s\n' "$actual"
    failures=$((failures + 1))
  fi
}

check_route "analyze framework orchestration and human-like engineer agents with domain knowledge" 'role=framework-manager .*tier=xhigh .*model=gpt-5\.5'
check_route "framework orchestration gap analysis for human-like engineer agents with domain knowledge" 'role=framework-manager .*tier=xhigh .*model=gpt-5\.5'
check_route "проанализируй оркестрацию фреймворка и агентов с доменными знаниями" 'role=framework-manager .*tier=xhigh .*model=gpt-5\.5'
check_route "аудит codex framework на human-like engineer поведение" 'role=framework-manager .*tier=xhigh .*model=gpt-5\.5'
check_route "проведи валидацию фреймворка на orchestration maturity" 'role=framework-manager .*tier=xhigh .*model=gpt-5\.5'
check_route "проверь статус нашего фреймворка что хорошо что плохо что легаси и грязь нужно удалить что мешает эффективно выжимать из codex больше чем просто промпт кодинг" 'role=framework-manager .*tier=xhigh .*model=gpt-5\.5'
check_route "уберем легаси и используем codex hooks как основной runtime" 'role=framework-manager .*tier=xhigh .*model=gpt-5\.5'
check_route "new skill for repo-native browser verification" 'role=framework-manager .*tier=high .*model=gpt-5\.5'
check_route "update routing rules for mobile tasks" 'role=framework-manager .*tier=high .*model=gpt-5\.5'
check_route "review GitHub PR #123 and check CI" 'role=reviewer .*tier=medium .*model=gpt-5\.5'
check_route "аудит безопасности зависимостей и CVE" 'role=auditor .*tier=medium .*model=gpt-5\.5'
check_route "напиши regression tests for checkout webhook" 'role=tester .*tier=medium .*model=gpt-5\.5'
check_route "fix checkout race condition across API and webhook handling" 'role=fixer .*tier=high .*model=gpt-5\.5'
check_route "исправь performance issue в backend service" 'role=fixer .*tier=medium .*model=gpt-5\.5'
check_route "create small config rename in single-file script" 'role=builder .*tier=low .*model=gpt-5\.4-mini'
check_route "design API contract for new billing service" 'role=architect .*tier=high .*model=gpt-5\.5'
check_route "спроектируй schema migration для payments" 'role=architect .*tier=high .*model=gpt-5\.5'
check_route "build RAG chatbot with prompt injection guardrails" 'role=builder-ai .*tier=high .*model=gpt-5\.5'
check_route "почини баг в backend endpoint авторизации" 'role=fixer .*tier=medium .*model=gpt-5\.5'
check_route "build n8n webhook chain with retry strategy" 'role=builder-n8n .*tier=high .*model=gpt-5\.5'
check_route "implement React Native offline sync" 'role=builder-mobile .*tier=medium .*model=gpt-5\.5'
check_route "deploy Kubernetes workload with observability" 'role=builder-infra .*tier=medium .*model=gpt-5\.5'
check_route "refactor duplicated backend service logic" 'role=refactorer .*tier=high .*model=gpt-5\.5'
check_route "создай PR with release summary" 'role=project-manager .*tier=low .*model=gpt-5\.4-mini'
check_route "estimate scope and cost for checkout migration" 'role=estimator .*tier=medium .*model=gpt-5\.5'

check_brief() {
  local task="$1"
  local output="$2"
  shift 2
  local pattern
  total=$((total + 1))
  CODEX_SKIP_BOOTSTRAP=1 CODEX_SKIP_REPO_REFRESH=1 bash "$ROOT/scripts/task-brief.sh" --task "$task" --output "$output" >/dev/null
  for pattern in "$@"; do
    if ! grep -Eq "$pattern" "$output"; then
      printf 'not ok %02d brief: %s\n' "$total" "$task"
      printf '  missing: %s\n' "$pattern"
      brief_failures=$((brief_failures + 1))
      failures=$((failures + 1))
      return 0
    fi
  done
  printf 'ok %02d brief: %s\n' "$total" "$task"
}

brief_dir="${TMPDIR:-/tmp}/codex-framework-eval"
mkdir -p "$brief_dir"
check_brief \
  "проанализируй оркестрацию фреймворка и агентов с доменными знаниями" \
  "$brief_dir/framework-orchestration-brief.md" \
  'Chosen owner: framework-manager' \
  'Reasoning depth: xhigh' \
  'Task flags: .*review.*strategic' \
  'Task shape: strategic' \
  'Primary skill: framework-management' \
  'framework-orchestration-audit' \
  'Primary named agent: framework-manager' \
  'Runtime spawn type: worker' \
  'Execution pattern: review-first'

check_brief \
  "проверь статус нашего фреймворка что хорошо что плохо что легаси и грязь нужно удалить что мешает эффективно выжимать из codex больше чем просто промпт кодинг" \
  "$brief_dir/framework-status-brief.md" \
  'Chosen owner: framework-manager' \
  'Reasoning depth: xhigh' \
  'Task flags: .*spec-driven.*review.*strategic' \
  'Task shape: strategic' \
  'Primary skill: framework-management' \
  'framework-orchestration-audit' \
  'Execution pattern: review-first'

check_brief \
  "Можем сделать комплексный аудит нашего фреймворка всех слоев. Какие дыры? Какие слабые места? Можно сказать что он лучше чем просто хороший промпт? все ли автоматизировано? Качество скилов, оркестрации?" \
  "$brief_dir/framework-full-audit-brief.md" \
  'Chosen owner: framework-manager' \
  'Reasoning depth: xhigh' \
  'Task flags: .*spec-driven.*review.*strategic' \
  'Task shape: strategic' \
  'Primary skill: framework-management' \
  'framework-orchestration-audit' \
  'Execution pattern: review-first'

check_plan() {
  local task="$1"
  local output="$2"
  shift 2
  local pattern
  total=$((total + 1))
  CODEX_SKIP_BOOTSTRAP=1 CODEX_SKIP_REPO_REFRESH=1 bash "$ROOT/scripts/plan.sh" --task "$task" --output "$output" >/dev/null
  for pattern in "$@"; do
    if ! grep -Eq "$pattern" "$output"; then
      printf 'not ok %02d plan: %s\n' "$total" "$task"
      printf '  missing: %s\n' "$pattern"
      failures=$((failures + 1))
      return 0
    fi
  done
  printf 'ok %02d plan: %s\n' "$total" "$task"
}

check_plan \
  "implement backend endpoint and frontend form in parallel" \
  "$brief_dir/fullstack-parallel-plan.md" \
  'Named agent: architect' \
  'Named agent: builder-backend' \
  'Named agent: builder-frontend' \
  'Named agent: tester' \
  'Parallel After Contract'

printf 'framework eval: %d checks, %d route/brief/plan failures\n' "$total" "$failures"

if [ "$failures" -ne 0 ]; then
  exit 1
fi
