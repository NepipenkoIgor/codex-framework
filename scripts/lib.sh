#!/bin/bash
set -euo pipefail

framework_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

project_root() {
  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    git rev-parse --show-toplevel
  else
    pwd
  fi
}

project_codex_dir() {
  printf '%s/.codex\n' "$(project_root)"
}

project_commands_file() {
  printf '%s/project.env\n' "$(project_codex_dir)"
}

detect_project_commands() {
  bash "$(framework_root)/scripts/detect-project-commands.sh" "$(project_root)"
}

load_project_commands() {
  local file
  file="$(project_commands_file)"
  if [ -f "$file" ]; then
    # shellcheck disable=SC1090
    . "$file"
  else
    eval "$(detect_project_commands)"
  fi
}

print_section() {
  printf '\n== %s ==\n' "$1"
}

fail() {
  echo "error: $*" >&2
  exit 1
}

warn() {
  echo "warn: $*"
}

info() {
  echo "$*"
}

role_emoji() {
  case "$1" in
    architect) echo "📐" ;;
    auditor) echo "🟪" ;;
    builder|builder-frontend|builder-backend|builder-infra|builder-mobile|builder-fullstack|builder-automation|builder-specialized) echo "🟢" ;;
    fixer) echo "🔴" ;;
    refactorer) echo "🔷" ;;
    reviewer) echo "🟠" ;;
    tester) echo "🟡" ;;
    estimator) echo "🟤" ;;
    project-manager) echo "🩵" ;;
    framework-manager) echo "🧰" ;;
    *) echo "⏺" ;;
  esac
}

role_alias() {
  case "$1" in
    architect) echo "arch" ;;
    auditor) echo "audit" ;;
    builder) echo "build" ;;
    builder-frontend) echo "build-fe" ;;
    builder-backend) echo "build-be" ;;
    builder-infra) echo "build-infra" ;;
    builder-mobile) echo "build-mobile" ;;
    builder-fullstack) echo "build-fs" ;;
    builder-automation) echo "build-auto" ;;
    builder-specialized) echo "build-spec" ;;
    fixer) echo "fix" ;;
    refactorer) echo "refact" ;;
    reviewer) echo "review" ;;
    tester) echo "test" ;;
    estimator) echo "est" ;;
    project-manager) echo "pm" ;;
    framework-manager) echo "fw" ;;
    *) echo "$1" ;;
  esac
}

model_tag() {
  case "$1" in
    low) echo "l" ;;
    medium) echo "m" ;;
    high) echo "h" ;;
    xhigh) echo "x" ;;
    *) echo "m" ;;
  esac
}

tier_model() {
  case "$1" in
    low) echo "codex-mini-latest" ;;
    medium) echo "gpt-5.4-mini" ;;
    high|xhigh) echo "gpt-5.4" ;;
    *) echo "gpt-5.4-mini" ;;
  esac
}

tier_reasoning() {
  case "$1" in
    low|medium|high|xhigh) echo "$1" ;;
    *) echo "medium" ;;
  esac
}

skill_icon() {
  case "$1" in
    *architecture*|api-design|ddd-patterns|workflow-engine-design|design-system-architecture) echo "🧠" ;;
    frontend-*|responsive-design|accessibility-*|dark-mode|seo-*|design-system-implement|ui-consistency-audit|advanced-forms|animation-motion|advanced-animation) echo "🎨" ;;
    backend-*|api-design|data-validation-design|audit-logging|payment-integration|search-implementation|caching-strategy|background-jobs|message-queue-patterns|file-upload-storage|resilience-patterns) echo "🛠️" ;;
    *test*|ci-status|verify|visual-regression|e2e-test|n8n-test) echo "🧪" ;;
    *security*|auth-security|dependency-audit|plugin-security-review|gdpr-compliance|llm-security) echo "🔐" ;;
    devops-ci|infrastructure-as-code|deployment-*|environment-management|kubernetes-workload|serverless-patterns) echo "⚙️" ;;
    automation-*|prompt-*|rag-pipeline|vector-database|ai-*|chatbot-implement|multimodal-processing|llm-evaluation) echo "🤖" ;;
    mobile-*|react-native-patterns) echo "📱" ;;
    analytics-implementation|reporting-dashboards|performance|performance-budgets|observability-design|error-tracking) echo "📊" ;;
    supabase-patterns|firebase-patterns|project-setup|process-hygiene|pr-review|pr-fix-comments|commit|spec|re-spec|docs-sync|status) echo "🌐" ;;
    *) echo "📚" ;;
  esac
}

decorate_skill_list() {
  local raw="$1"
  local skill
  [ -n "$raw" ] && [ "$raw" != "none" ] || return 0
  printf '%s\n' "$raw" | tr ',' '\n' | while IFS= read -r skill; do
    skill="$(printf '%s' "$skill" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -n "$skill" ] || continue
    printf '%s %s\n' "$(skill_icon "$skill")" "$skill"
  done | awk 'BEGIN { first = 1 } { if (!first) printf ", "; printf "%s", $0; first = 0 } END { printf "\n" }' | tr -d '\n'
}

has_command() {
  command -v "$1" >/dev/null 2>&1
}

search_file_regex() {
  local pattern="$1"
  local file="$2"
  if has_command rg; then
    rg -q "$pattern" "$file"
  else
    grep -Eq "$pattern" "$file"
  fi
}

search_tree_regex() {
  local pattern="$1"
  local path="$2"
  local include_glob="${3:-}"
  if has_command rg; then
    if [ -n "$include_glob" ]; then
      rg -n "$pattern" "$path" -g "$include_glob" >/dev/null 2>&1
    else
      rg -n "$pattern" "$path" >/dev/null 2>&1
    fi
  else
    if [ -n "$include_glob" ]; then
      grep -ERn --include="$include_glob" "$pattern" "$path" >/dev/null 2>&1
    else
      grep -ERn "$pattern" "$path" >/dev/null 2>&1
    fi
  fi
}

current_branch() {
  git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "no-git"
}

git_changed_files() {
  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    git diff --name-only HEAD
  fi
}

git_has_changes() {
  if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
    return 1
  fi
  [ -n "$(git status --porcelain)" ]
}

spec_root() {
  printf '%s/specs\n' "$(project_codex_dir)"
}

ensure_spec_root() {
  mkdir -p "$(spec_root)"
}

run_root() {
  local preferred fallback project_name
  preferred="$(project_codex_dir)/runs"
  if mkdir -p "$preferred" >/dev/null 2>&1; then
    printf '%s\n' "$preferred"
    return 0
  fi
  project_name="$(basename "$(project_root)")"
  fallback="/tmp/ai-codex-framework/$project_name/runs"
  mkdir -p "$fallback"
  printf '%s\n' "$fallback"
}

ensure_run_root() {
  mkdir -p "$(run_root)"
}

timestamp_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

log_task_decision() {
  local prompt="$1"
  local role="$2"
  local skills="$3"
  local tier="$4"
  local model="$5"
  local reasoning="$6"
  ensure_run_root
  local file
  file="$(run_root)/$(date -u +"%Y%m%dT%H%M%SZ").log"
  cat > "$file" <<EOF
timestamp=$(timestamp_utc)
role=$role
skills=$skills
tier=$tier
model=$model
reasoning=$reasoning
prompt=$prompt
EOF
  printf '%s\n' "$file"
}

ensure_project_bootstrap() {
  bash "$(framework_root)/scripts/bootstrap-project.sh" "${1:-$(project_root)}" --silent
}

active_spec_file() {
  local root latest
  root="$(spec_root)"
  if [ ! -d "$root" ]; then
    return 1
  fi
  latest="$(find "$root" -mindepth 2 -maxdepth 2 -name spec.md -print | xargs ls -t 2>/dev/null | head -n 1 || true)"
  [ -n "$latest" ] || return 1
  printf '%s\n' "$latest"
}

spec_counts() {
  local file="$1"
  local done failed pending
  done="$(grep -o '✓' "$file" 2>/dev/null | wc -l | tr -d ' ')"
  failed="$(grep -o '✗' "$file" 2>/dev/null | wc -l | tr -d ' ')"
  pending="$(grep -o '☐' "$file" 2>/dev/null | wc -l | tr -d ' ')"
  printf '%s %s %s\n' "$done" "$failed" "$pending"
}

detect_local_url() {
  local ports port
  ports="${1:-3000 5173 8000 8080 4173}"
  for port in $ports; do
    if has_command lsof && lsof -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
      printf 'http://localhost:%s\n' "$port"
      return 0
    fi
  done
  return 1
}

run_named_command() {
  local name="$1"
  local cmd="${2:-}"
  if [ -z "$cmd" ]; then
    warn "no command configured for $name"
    return 1
  fi
  print_section "$name"
  sh -lc "$cmd"
}

conventional_commit_valid() {
  printf '%s\n' "$1" | grep -Eq '^(feat|fix|refactor|test|chore|docs|style|perf)(\([a-z0-9._/-]+\))?: [[:lower:]].{0,68}$'
}
