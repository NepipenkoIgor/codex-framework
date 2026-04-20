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
  work <issue-number-or-url> [--refresh]
  health
  preflight
  capabilities [path]
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
  pr-ready
  pr-body [--output <file>]
  pr-create [--title "<title>"] [--body-file <file>] [--base <branch>] [--draft]
  safe-commit "<message>" [--all]
  bootstrap-project [path]
EOF
}

route_task() {
  local task
  local tier role skills reasoning model
  task="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  local narrow_task=false
  if printf '%s' "$task" | grep -Eq 'single-file|single file|one file|targeted|small fix|minor fix|typo|rename|copy change|small config|simple docs|narrow'; then
    narrow_task=true
  fi
  if printf '%s' "$task" | grep -Eq 'framework health|new skill|role update|routing|codex framework'; then
    role="framework-manager"; skills="framework-management"; tier="high"
  elif printf '%s' "$task" | grep -Eq 'dependency audit|security audit|cve|plugin review'; then
    role="auditor"; skills="security-audit,dependency-audit,plugin-security-review"; tier="medium"
  elif printf '%s' "$task" | grep -Eq 'create pr|open pr|prepare pr|publish pr|pull request summary'; then
    role="project-manager"; skills="project-setup,process-hygiene"; tier="low"
  elif printf '%s' "$task" | grep -Eq 'backlog|sprint|milestone|ticket|repo setup'; then
    role="project-manager"; skills="project-setup,process-hygiene"; tier="low"
  elif printf '%s' "$task" | grep -Eq 'review|audit|pr'; then
    role="reviewer"; skills="frontend-review,backend-review,security-audit"; tier="medium"
    [ "$narrow_task" = true ] && tier="low"
  elif printf '%s' "$task" | grep -Eq 'test|coverage|regression|e2e'; then
    role="tester"; skills="frontend-test,backend-test"; tier="medium"
    [ "$narrow_task" = true ] && tier="low"
  elif printf '%s' "$task" | grep -Eq 'refactor|simplify|migrate|clean up'; then
    role="refactorer"; skills="frontend-refactor,backend-refactor"; tier="high"
    [ "$narrow_task" = true ] && tier="medium"
  elif printf '%s' "$task" | grep -Eq 'fix|bug|crash|debug|wrong behavior|performance|failure|incident|race condition'; then
    role="fixer"; skills="frontend-debug,backend-debug"; tier="medium"
    [ "$narrow_task" = true ] && tier="low"
    if printf '%s' "$task" | grep -Eq 'across|cross-system|cross system|multi-system|multi service|migration|webhook|concurrency|deadlock|race condition|distributed'; then
      tier="high"
    fi
  elif printf '%s' "$task" | grep -Eq 'design|architecture|schema|api contract|technical plan|new dependency'; then
    role="architect"; skills="api-design,backend-architecture,frontend-architecture"; tier="high"
  elif printf '%s' "$task" | grep -Eq 'react native|expo|flutter|ios|android|mobile'; then
    role="builder-mobile"; skills="mobile-implement,accessibility-implement"; tier="medium"
  elif printf '%s' "$task" | grep -Eq 'next\.js|nextjs|blazor|app router|razor|page and api|full-stack framework'; then
    role="builder-fullstack"; skills="frontend-implement,backend-implement,api-design"; tier="high"
  elif printf '%s' "$task" | grep -Eq 'n8n|workflow|automation| ai |llm|rag|prompt|vector|agent'; then
    role="builder-automation"; skills="automation-ai-workflows,llm-security,prompt-engineering"; tier="high"
  elif printf '%s' "$task" | grep -Eq 'docker|kubernetes|infra|deploy|ci|cd'; then
    role="builder-infra"; skills="devops-ci,infrastructure-as-code,deployment-validation"; tier="medium"
  elif printf '%s' "$task" | grep -Eq 'ui|component|page|frontend|styling|form|accessibility'; then
    role="builder-frontend"; skills="frontend-implement,accessibility-implement"; tier="medium"
    [ "$narrow_task" = true ] && tier="low"
  elif printf '%s' "$task" | grep -Eq 'api|backend|service|auth|job|database|persistence'; then
    role="builder-backend"; skills="backend-implement,api-design"; tier="medium"
    [ "$narrow_task" = true ] && tier="low"
  elif printf '%s' "$task" | grep -Eq 'typo|rename|copy change|small config|simple docs|single-file'; then
    role="builder"; skills="frontend-implement,backend-implement"; tier="low"
  else
    role="builder"; skills="frontend-implement,backend-implement"; tier="medium"
  fi
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
  exec codex -m "$model" "Read $brief_file first, then execute the task."
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
  health) bash "$ROOT/scripts/framework-health.sh" ;;
  preflight) bash "$ROOT/scripts/preflight.sh" ;;
  capabilities) bash "$ROOT/scripts/capabilities.sh" "${1:-$PWD}" ;;
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
  pr-ready) bash "$ROOT/scripts/pr-ready.sh" ;;
  pr-body) bash "$ROOT/scripts/pr-body.sh" "$@" ;;
  pr-create) bash "$ROOT/scripts/pr-create.sh" "$@" ;;
  safe-commit) bash "$ROOT/scripts/safe-commit.sh" "$@" ;;
  bootstrap-project) bash "$ROOT/scripts/bootstrap-project.sh" "${1:-$PWD}" ;;
  *) usage; exit 1 ;;
esac
