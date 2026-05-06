#!/bin/bash
set -euo pipefail

SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
ROOT="$(cd -P "$(dirname "$SOURCE")/.." && pwd)"
. "$ROOT/scripts/lib.sh"

usage() {
  cat <<EOF
codex-fw commands:
  help
  start [path]
  session [--task "<task text>"]
  work <issue-number-or-url> [--refresh] [--resume] [--cleanup|--cleanup-all]
  worktrees
  health
  preflight
  doctor [path]
  capabilities [path]
  intelligence [path] [task]
  memory <init|status|context|search|add-episode|add-decision|compact|prune|get> ...
  detect-features [path]
  detect-conventions [path]
  github-status
  github-issue-fetch <issue-number-or-url>
  github-pr-context <pr-number-or-url>
  github-review-prep <pr-number-or-url>
  route "<task text>"
  plan "<task text>" [spec-file]
  brief "<task text>" [spec-file]
  run "<task text>"
  go "<task text>"
  detect-stack [path]
  detect-commands [path]
  refresh-commands [path]
  spec-status [issue]
  browser-verify [spec-file]
  post-change-check
  guard-scan [--staged|--changed|--all] [file...]
  quality-check [--staged|--changed|--all] [file...]
  install-git-hooks [path]
  handoff <init|register|status|decision|blocker|get|clear> ...
  retry-state <init|register|increment|set-model|get|clear> ...
  pr-ready [--base <branch>]
  pr-publish [--base <branch>]
  pr-body [--output <file>]
  pr-create [--title "<title>"] [--body-file <file>] [--base <branch>] [--draft]
  safe-commit "<message>" [--all]
  bootstrap-project [path]
EOF
}

show_worktrees() {
  local rows
  rows="$(bash "$ROOT/scripts/issue-worktrees.sh" list "${1:-$PWD}")"
  if [ -z "$rows" ]; then
    printf 'no issue worktrees found\n'
    return 0
  fi
  {
    printf 'ISSUE\tSHA\tBASE\tSTATE\tBRANCH\tPATH\tCREATED\n'
    printf '%s\n' "$rows" | awk -F '\t' '{ print $1 "\t" ($2 ? $2 : "-") "\t" $3 "\t" $4 "\t" $5 "\t" $6 "\t" $7 }'
  } | column -t -s $'\t'
}

route_task() {
  local task
  local tier role skills reasoning model shape
  task="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  shape="$(classify_task_shape "$task")"
  role="$(choose_role_from_repo_intelligence "$task" "$shape")"
  tier="$(choose_tier_from_role_and_task "$role" "$task" "$shape")"
  case "$role" in
    framework-manager) skills="framework-management,framework-orchestration-audit,process-hygiene,docs-sync" ;;
    auditor) skills="security-audit,dependency-audit,plugin-security-review,audit-logging,incident-response" ;;
    project-manager) skills="project-setup,process-hygiene,release-management,adr-management,docs-sync" ;;
    reviewer) skills="frontend-review,backend-review,security-audit,ui-consistency-audit,accessibility-audit,performance,docs-sync" ;;
    tester) skills="frontend-test,backend-test,e2e-test,visual-regression,contract-testing" ;;
    refactorer) skills="frontend-refactor,backend-refactor,ui-consistency-audit,code-reuse,performance" ;;
    fixer) skills="frontend-debug,backend-debug,performance,security-audit,accessibility-audit" ;;
    architect) skills="api-design,backend-architecture,frontend-architecture,design-system-architecture,data-modeling,database-migration,ddd-patterns,observability-design,adr-management,security-audit" ;;
    builder-mobile) skills="mobile-implement,accessibility-implement,animation-motion,mobile-deployment,deployment-validation,offline-sync-design,auth-security" ;;
    builder-fullstack) skills="frontend-implement,backend-implement,api-design,accessibility-implement,data-validation-design,docs-sync" ;;
    builder-n8n) skills="automation-n8n-implement,automation-n8n-architecture,automation-n8n-debug,n8n-test,llm-security,prompt-management" ;;
    builder-ai) skills="automation-ai-workflows,llm-security,prompt-engineering,ai-agent-architecture,prompt-management,rag-pipeline,vector-database,ai-streaming,multimodal-processing" ;;
    builder-automation) skills="automation-ai-workflows,llm-security,prompt-engineering,automation-n8n-architecture,automation-n8n-debug,n8n-test,prompt-management,rag-pipeline,vector-database" ;;
    builder-infra) skills="devops-ci,infrastructure-as-code,deployment-validation,deployment-strategies,environment-management,kubernetes-workload,observability-design,incident-response" ;;
    builder-frontend) skills="frontend-implement,accessibility-implement,design-system-implement,animation-motion,responsive-design,ui-consistency-audit" ;;
    builder-backend) skills="backend-implement,api-design,data-validation-design,auth-security,database-migration,database-optimization,docs-sync,observability-design" ;;
    *) skills="frontend-implement,backend-implement" ;;
  esac
  reasoning="$(tier_reasoning "$tier")"
  model="$(tier_model "$tier")"
  echo "role=$role skills=$skills tier=$tier model=$model reasoning=$reasoning"
}

run_task() {
  local prompt="$1"
  local decision role skills tier model reasoning log_file brief_file
  decision="$(route_task "$prompt")"
  role="$(printf '%s\n' "$decision" | sed -n 's/.*role=\([^ ]*\).*/\1/p')"
  skills="$(printf '%s\n' "$decision" | sed -n 's/.*skills=\([^ ]*\).*/\1/p')"
  tier="$(printf '%s\n' "$decision" | sed -n 's/.*tier=\([^ ]*\).*/\1/p')"
  model="$(printf '%s\n' "$decision" | sed -n 's/.*model=\([^ ]*\).*/\1/p')"
  reasoning="$(printf '%s\n' "$decision" | sed -n 's/.*reasoning=\([^ ]*\).*/\1/p')"
  log_file="$(
    . "$ROOT/scripts/lib.sh"
    ensure_project_bootstrap "$PWD"
    log_task_decision "$prompt" "$role" "$skills" "$tier" "$model" "$reasoning"
  )"
  brief_file="$(bash "$ROOT/scripts/task-brief.sh" --task "$prompt")"
  printf 'role=%s\nskills=%s\ntier=%s\nmodel=%s\nreasoning=%s\nlog=%s\n' \
    "$role" "$skills" "$tier" "$model" "$reasoning" "$log_file"
  codex_exec -m "$model" "Read $brief_file first, then execute the task."
}

start_cmd() {
  local target="${1:-$PWD}"
  bash "$ROOT/scripts/bootstrap-project.sh" "$target"
  (
    cd "$target"
    bash "$ROOT/scripts/preflight.sh"
    printf '\n-- route hint --\n'
    echo 'Use: codex-fw route "<task text>"'
    printf '\n-- spec status --\n'
    bash "$ROOT/scripts/spec-status.sh" 2>/dev/null || echo "no active spec found"
  )
}

brief_task() {
  local task="$1"
  local spec_file="${2:-}"
  if [ -n "$spec_file" ]; then
    bash "$ROOT/scripts/task-brief.sh" --task "$task" --spec "$spec_file"
  else
    bash "$ROOT/scripts/task-brief.sh" --task "$task"
  fi
}

plan_task() {
  local task="$1"
  local spec_file="${2:-}"
  if [ -n "$spec_file" ]; then
    bash "$ROOT/scripts/plan.sh" --task "$task" --spec "$spec_file"
  else
    bash "$ROOT/scripts/plan.sh" --task "$task"
  fi
}

cmd="${1:-help}"
shift || true

case "$cmd" in
  help|-h|--help) usage ;;
  start) start_cmd "${1:-$PWD}" ;;
  session) bash "$ROOT/scripts/session-start.sh" "$@" ;;
  work) [ $# -ge 1 ] || usage; bash "$ROOT/scripts/work.sh" "$@" ;;
  worktrees) show_worktrees "${1:-$PWD}" ;;
  health) bash "$ROOT/scripts/framework-health.sh" ;;
  preflight) bash "$ROOT/scripts/preflight.sh" ;;
  doctor) bash "$ROOT/scripts/doctor.sh" "${1:-$PWD}" ;;
  capabilities) bash "$ROOT/scripts/capabilities.sh" "${1:-$PWD}" ;;
  intelligence) bash "$ROOT/scripts/detect-repo-intelligence.sh" "${1:-$PWD}" "${2:-}" ;;
  memory) [ $# -ge 1 ] || usage; bash "$ROOT/scripts/memory-state.sh" "$@" ;;
  detect-features) bash "$ROOT/scripts/detect-project-features.sh" "${1:-$PWD}" ;;
  detect-conventions) bash "$ROOT/scripts/detect-project-conventions.sh" "${1:-$PWD}" "${2:-}" ;;
  github-status) bash "$ROOT/scripts/github-status.sh" ;;
  github-issue-fetch) [ $# -ge 1 ] || usage; bash "$ROOT/scripts/github-issue-fetch.sh" "$1" ;;
  github-pr-context) [ $# -ge 1 ] || usage; bash "$ROOT/scripts/github-pr-context.sh" "$1" ;;
  github-review-prep) [ $# -ge 1 ] || usage; bash "$ROOT/scripts/github-review-prep.sh" "$1" ;;
  route) [ $# -ge 1 ] || usage; route_task "$*" ;;
  plan) [ $# -ge 1 ] || usage; plan_task "$1" "${2:-}" ;;
  brief) [ $# -ge 1 ] || usage; brief_task "$1" "${2:-}" ;;
  run) [ $# -ge 1 ] || usage; run_task "$*" ;;
  go) [ $# -ge 1 ] || usage; bash "$ROOT/scripts/session-start.sh" --task "$*" ;;
  detect-stack) bash "$ROOT/scripts/detect-project-stack.sh" "${1:-$PWD}" ;;
  detect-commands) bash "$ROOT/scripts/detect-project-commands.sh" "${1:-$PWD}" ;;
  refresh-commands)
    target="${1:-$PWD}"
    mkdir -p "$target/.codex"
    bash "$ROOT/scripts/detect-project-commands.sh" "$target" > "$target/.codex/project.env"
    printf '%s\n' "$target/.codex/project.env"
    ;;
  spec-status) bash "$ROOT/scripts/spec-status.sh" "$@" ;;
  browser-verify) bash "$ROOT/scripts/browser-verify.sh" "$@" ;;
  post-change-check) bash "$ROOT/scripts/post-change-check.sh" ;;
  guard-scan) bash "$ROOT/scripts/guard-scan.sh" "$@" ;;
  quality-check) bash "$ROOT/scripts/quality-check.sh" "$@" ;;
  install-git-hooks) bash "$ROOT/scripts/install-git-hooks.sh" "${1:-$PWD}" ;;
  handoff) [ $# -ge 1 ] || usage; bash "$ROOT/scripts/handoff-state.sh" "$@" ;;
  retry-state) [ $# -ge 1 ] || usage; bash "$ROOT/scripts/retry-state.sh" "$@" ;;
  pr-ready) bash "$ROOT/scripts/pr-ready.sh" "$@" ;;
  pr-publish) bash "$ROOT/scripts/pr-publish.sh" "$@" ;;
  pr-body) bash "$ROOT/scripts/pr-body.sh" "$@" ;;
  pr-create) bash "$ROOT/scripts/pr-create.sh" "$@" ;;
  safe-commit) bash "$ROOT/scripts/safe-commit.sh" "$@" ;;
  bootstrap-project) bash "$ROOT/scripts/bootstrap-project.sh" "${1:-$PWD}" ;;
  *) usage; exit 1 ;;
esac
