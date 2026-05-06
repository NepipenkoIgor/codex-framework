#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/scripts/lib.sh"

score_total=0
score_max=0
failures=0

metric() {
  local name="$1"
  local points="$2"
  local max="$3"
  local note="$4"
  score_total=$((score_total + points))
  score_max=$((score_max + max))
  if [ "$points" -eq "$max" ]; then
    printf 'ok %-34s %2d/%2d %s\n' "$name" "$points" "$max" "$note"
  else
    printf 'gap %-33s %2d/%2d %s\n' "$name" "$points" "$max" "$note"
    failures=$((failures + 1))
  fi
}

count_eval_cases() {
  grep -c '^check_route ' "$ROOT/scripts/framework-eval.sh"
}

count_brief_cases() {
  grep -c '^check_brief ' "$ROOT/scripts/framework-eval.sh"
}

all_routing_skills_exist() {
  local missing
  missing="$(awk '
    $1 == "skills:" { in_skills=1; next }
    in_skills && $1 == "-" { print $2; next }
    in_skills && $1 != "-" { in_skills=0 }
  ' "$ROOT/routing.yaml" | sort -u | while IFS= read -r skill; do
    [ -z "$skill" ] && continue
    [ -d "$ROOT/skills/$skill" ] || printf '%s\n' "$skill"
  done)"
  [ -z "$missing" ]
}

all_role_briefs_exist() {
  local missing
  missing="$(awk '
    $1 == "roles:" { in_roles=1; next }
    in_roles && $1 == "verification:" { in_roles=0 }
    in_roles && $0 ~ /^  [a-z0-9-]+:$/ { gsub(":", "", $1); print $1 }
  ' "$ROOT/routing.yaml" | while IFS= read -r role; do
    [ -z "$role" ] && continue
    [ -f "$ROOT/agents/$role.md" ] || printf '%s\n' "$role"
  done)"
  [ -z "$missing" ]
}

role_briefs_have_recommended_skills() {
  ! find "$ROOT/agents" -maxdepth 1 -name '*.md' -exec sh -c '
    for file do
      grep -q "^recommended_skills:" "$file" || exit 1
    done
  ' sh {} +
}

has_framework_routing_cases() {
  grep -q 'framework orchestration' "$ROOT/scripts/framework-eval.sh" \
    && grep -q 'оркестрацию фреймворка' "$ROOT/scripts/framework-eval.sh"
}

has_brief_eval_case() {
  grep -q '^check_brief ' "$ROOT/scripts/framework-eval.sh"
}

has_contract_policy() {
  grep -q 'Contract-bearing tasks should route to `high`' "$ROOT/ORCHESTRATOR_REFERENCE.md" \
    && grep -q 'contract_task="yes"' "$ROOT/scripts/lib.sh"
}

has_requirement_gate() {
  grep -q 'Requirement Check' "$ROOT/scripts/task-brief.sh" \
    && grep -q 'requires_requirement_check' "$ROOT/scripts/lib.sh"
}

has_handoff_controls() {
  [ -f "$ROOT/scripts/handoff-state.sh" ] \
    && grep -q 'Contract required' "$ROOT/scripts/task-brief.sh" \
    && grep -q 'handoff_id' "$ROOT/scripts/task-brief.sh"
}

has_runtime_capabilities() {
  [ -f "$ROOT/CODEX.capabilities.md" ] \
    && grep -q 'capabilities_report' "$ROOT/scripts/task-brief.sh" \
    && grep -q 'CODEX_WAIT_FOR_GO' "$ROOT/CODEX.md"
}

has_verification_gates() {
  [ -f "$ROOT/scripts/guard-scan.sh" ] \
    && [ -f "$ROOT/scripts/quality-check.sh" ] \
    && [ -f "$ROOT/scripts/framework-health.sh" ] \
    && [ -f "$ROOT/scripts/framework-eval.sh" ]
}

has_drift_checker() {
  [ -f "$ROOT/scripts/framework-drift-check.sh" ] \
    && grep -q 'check_route_probe estimator' "$ROOT/scripts/framework-drift-check.sh"
}

has_benchmark_dataset() {
  [ -f "$ROOT/scripts/framework-benchmark.sh" ] \
    && [ -f "$ROOT/templates/framework-benchmark.tsv" ] \
    && [ "$(grep -cv '^#' "$ROOT/templates/framework-benchmark.tsv")" -ge 20 ]
}

has_skill_quality_audit() {
  [ -f "$ROOT/scripts/framework-skill-quality.sh" ] \
    && grep -q 'frontend design system reuse' "$ROOT/scripts/framework-skill-quality.sh" \
    && grep -q 'backend no hardcode policy' "$ROOT/scripts/framework-skill-quality.sh"
}

has_skill_corpus_audit() {
  [ -f "$ROOT/scripts/framework-skill-corpus-audit.sh" ] \
    && grep -q 'average_score' "$ROOT/scripts/framework-skill-corpus-audit.sh"
}

runtime_state_is_untracked() {
  [ -z "$(git -C "$ROOT" ls-files .codex .githooks)" ]
}

gitignore_blocks_runtime_state() {
  [ -f "$ROOT/.gitignore" ] \
    && grep -qx '/.codex/cache/' "$ROOT/.gitignore" \
    && grep -qx '/.codex/runs/' "$ROOT/.gitignore" \
    && grep -qx '/.codex/specs/' "$ROOT/.gitignore" \
    && grep -qx '/.codex/project.env' "$ROOT/.gitignore" \
    && grep -qx '/.codex/memory/' "$ROOT/.gitignore" \
    && grep -qx '/.githooks/' "$ROOT/.gitignore"
}

core_library_size_score() {
  local lines
  lines="$(wc -l < "$ROOT/scripts/lib.sh" | tr -d ' ')"
  if [ "$lines" -le 900 ]; then
    printf '10:%s lines' "$lines"
  elif [ "$lines" -le 1500 ]; then
    printf '5:%s lines; split soon' "$lines"
  else
    printf '0:%s lines; split scripts/lib.sh into focused modules' "$lines"
  fi
}

pr_flow_is_explicit() {
  grep -q -- '--head "$HEAD_BRANCH"' "$ROOT/scripts/pr-create.sh" \
    && grep -q -- '--base "$BASE_BRANCH"' "$ROOT/scripts/pr-create.sh" \
    && grep -q 'codex/\*)' "$ROOT/scripts/pr-ready.sh" \
    && grep -q 'latest-pr-ready.env' "$ROOT/scripts/pr-ready.sh" \
    && grep -q '## Test Plan' "$ROOT/scripts/pr-body.sh"
}

strict_maturity_threshold() {
  local pct
  pct=$((score_total * 100 / score_max))
  [ "$pct" -ge 85 ]
}

if all_routing_skills_exist; then metric "routing skills exist" 10 10 "all routing.yaml skills resolve"; else metric "routing skills exist" 0 10 "missing skill directories"; fi
if all_role_briefs_exist; then metric "role briefs exist" 10 10 "all routing.yaml roles have agents/*.md"; else metric "role briefs exist" 0 10 "missing role brief"; fi
if role_briefs_have_recommended_skills; then metric "role skill declarations" 10 10 "all role briefs declare recommended_skills"; else metric "role skill declarations" 0 10 "some role briefs lack recommended_skills"; fi

eval_cases="$(count_eval_cases)"
if [ "$eval_cases" -ge 20 ]; then metric "golden route coverage" 10 10 "$eval_cases route cases"; else metric "golden route coverage" 5 10 "$eval_cases route cases"; fi
if has_framework_routing_cases; then metric "multilingual framework eval" 10 10 "English and Russian framework cases present"; else metric "multilingual framework eval" 0 10 "missing multilingual framework cases"; fi
if has_brief_eval_case; then metric "generated brief eval" 10 10 "$(count_brief_cases) brief case present"; else metric "generated brief eval" 0 10 "missing brief-level eval"; fi

if has_contract_policy; then metric "contract-first controls" 10 10 "contract tasks route high"; else metric "contract-first controls" 0 10 "missing contract-first enforcement"; fi
if has_requirement_gate; then metric "requirement gate" 10 10 "requirement-sensitive flow exists"; else metric "requirement gate" 0 10 "missing requirement gate"; fi
if has_handoff_controls; then metric "handoff controls" 10 10 "handoff state wired into briefs"; else metric "handoff controls" 0 10 "missing handoff controls"; fi
if has_runtime_capabilities; then metric "runtime capability model" 10 10 "capabilities and approval knobs visible"; else metric "runtime capability model" 0 10 "missing capability model"; fi
if has_verification_gates; then metric "verification gates" 10 10 "guard, quality, health, eval present"; else metric "verification gates" 0 10 "missing verification gates"; fi
if has_drift_checker; then metric "source drift detection" 10 10 "routing roles and probes checked"; else metric "source drift detection" 0 10 "missing drift checker"; fi
if has_benchmark_dataset; then metric "benchmark dataset" 10 10 "routing benchmark dataset present"; else metric "benchmark dataset" 0 10 "missing benchmark dataset"; fi
if has_skill_quality_audit; then metric "skill quality coverage" 10 10 "baseline engineering policies checked"; else metric "skill quality coverage" 0 10 "missing skill quality audit"; fi
if has_skill_corpus_audit; then metric "skill corpus scorecard" 10 10 "all skills can be scored"; else metric "skill corpus scorecard" 0 10 "missing corpus audit"; fi
if runtime_state_is_untracked; then metric "runtime state untracked" 10 10 ".codex and .githooks stay out of git"; else metric "runtime state untracked" 0 10 "tracked .codex/.githooks files create status drift"; fi
if gitignore_blocks_runtime_state; then metric "runtime gitignore policy" 10 10 "local state ignored"; else metric "runtime gitignore policy" 0 10 "missing runtime ignore rules"; fi
if pr_flow_is_explicit; then metric "explicit PR flow" 10 10 "base/head, report, test plan, codex/* guard"; else metric "explicit PR flow" 0 10 "PR flow can drift from intended protocol"; fi

lib_score="$(core_library_size_score)"
metric "core library modularity" "${lib_score%%:*}" 10 "${lib_score#*:}"

printf 'maturity score: %d/%d\n' "$score_total" "$score_max"

if ! strict_maturity_threshold; then
  exit 1
fi
