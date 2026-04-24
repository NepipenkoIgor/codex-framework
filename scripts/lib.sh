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

project_git_hooks_dir() {
  printf '%s/.githooks\n' "$(project_root)"
}

project_commands_file() {
  printf '%s/project.env\n' "$(project_codex_dir)"
}

project_cache_dir() {
  local preferred fallback project_name probe
  preferred="$(project_codex_dir)/cache"
  if mkdir -p "$preferred" >/dev/null 2>&1; then
    probe="$preferred/.write-test.$$"
    if touch "$probe" >/dev/null 2>&1; then
      rm -f "$probe"
      printf '%s\n' "$preferred"
      return 0
    fi
  fi
  project_name="$(basename "$(project_root)")"
  fallback="/tmp/ai-codex-framework/$project_name/cache"
  mkdir -p "$fallback"
  printf '%s\n' "$fallback"
}

repo_intelligence_fingerprint() {
  local root="${1:-$(project_root)}"
  local files=()
  local path
  for path in \
    "$root/package.json" \
    "$root/tsconfig.json" \
    "$root/pnpm-lock.yaml" \
    "$root/yarn.lock" \
    "$root/package-lock.json" \
    "$root/bun.lock" \
    "$root/bun.lockb" \
    "$root/go.mod" \
    "$root/Cargo.toml" \
    "$root/pubspec.yaml" \
    "$root/pyproject.toml" \
    "$root/requirements.txt" \
    "$root/tailwind.config.js" \
    "$root/tailwind.config.cjs" \
    "$root/tailwind.config.mjs" \
    "$root/tailwind.config.ts" \
    "$root/.codex/project.env"
  do
    [ -f "$path" ] && files+=("$path")
  done
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    files+=("$path")
  done <<EOF
$(find "$root" -maxdepth 2 \( -name '*.csproj' -o -name '*.sln' -o -path '*/src/components/ui/*' -o -path '*/components/ui/*' \) -type f 2>/dev/null | sort | head -n 20)
EOF
  if [ "${#files[@]}" -eq 0 ]; then
    printf 'none\n'
    return 0
  fi
  {
    for path in "${files[@]}"; do
      [ -f "$path" ] || continue
      printf '%s|' "${path#$root/}"
      wc -c < "$path" | tr -d ' '
      printf '|'
      if stat -f '%m' "$path" >/dev/null 2>&1; then
        stat -f '%m' "$path"
      else
        stat -c '%Y' "$path"
      fi
      printf '\n'
    done
  } | shasum | awk '{print $1}'
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

join_by() {
  local delimiter="$1"
  shift || true
  local first=true
  local value
  for value in "$@"; do
    if [ "$first" = true ]; then
      printf '%s' "$value"
      first=false
    else
      printf '%s%s' "$delimiter" "$value"
    fi
  done
}

role_emoji() {
  case "$1" in
    architect) echo "📐" ;;
    auditor) echo "🟪" ;;
    builder|builder-frontend|builder-backend|builder-infra|builder-mobile|builder-fullstack|builder-automation|builder-ai|builder-n8n|builder-specialized) echo "🟢" ;;
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
    builder-ai) echo "build-ai" ;;
    builder-n8n) echo "build-n8n" ;;
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
    medium) echo "gpt-5.4" ;;
    high|xhigh) echo "gpt-5.4" ;;
    *) echo "gpt-5.4" ;;
  esac
}

tier_reasoning() {
  case "$1" in
    low|medium|high|xhigh) echo "$1" ;;
    *) echo "medium" ;;
  esac
}

codex_approval_mode() {
  printf '%s\n' "${CODEX_APPROVAL_MODE:-never}"
}

codex_sandbox_mode() {
  printf '%s\n' "${CODEX_SANDBOX_MODE:-danger-full-access}"
}

codex_use_full_auto() {
  case "${CODEX_FULL_AUTO:-0}" in
    1|true|TRUE|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

codex_runtime_args() {
  local approval sandbox
  approval="$(codex_approval_mode)"
  sandbox="$(codex_sandbox_mode)"
  [ -n "$approval" ] && [ "$approval" != "inherit" ] && printf '%s\n' "-a" "$approval"
  [ -n "$sandbox" ] && [ "$sandbox" != "inherit" ] && printf '%s\n' "-s" "$sandbox"
  codex_use_full_auto && printf '%s\n' "--full-auto"
}

codex_exec() {
  local -a args
  while IFS= read -r arg; do
    [ -n "$arg" ] || continue
    args+=("$arg")
  done < <(codex_runtime_args)
  exec codex "${args[@]}" "$@"
}

codex_run() {
  local -a args
  while IFS= read -r arg; do
    [ -n "$arg" ] || continue
    args+=("$arg")
  done < <(codex_runtime_args)
  command codex "${args[@]}" "$@"
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
  local preferred fallback project_name probe
  preferred="$(project_codex_dir)/runs"
  if mkdir -p "$preferred" >/dev/null 2>&1; then
    probe="$preferred/.write-test.$$"
    if touch "$probe" >/dev/null 2>&1; then
      rm -f "$probe"
      printf '%s\n' "$preferred"
      return 0
    fi
  fi
  project_name="$(basename "$(project_root)")"
  fallback="/tmp/ai-codex-framework/$project_name/runs"
  mkdir -p "$fallback"
  printf '%s\n' "$fallback"
}

ensure_run_root() {
  mkdir -p "$(run_root)"
}

ensure_cache_dir() {
  mkdir -p "$(project_cache_dir)"
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

task_contains() {
  local task_lc="$1"
  local pattern="$2"
  printf '%s' "$task_lc" | grep -Eq "$pattern"
}

stack_has() {
  local stack_csv="$1"
  local token="$2"
  printf ',%s,' "$stack_csv" | grep -q ",$token,"
}

detect_task_flags() {
  local task_lc="$1"
  local stack_csv="$2"
  local flags=()

  task_contains "$task_lc" 'issue|spec|acceptance criteria|gap analysis|missing' && flags+=("spec-driven")
  task_contains "$task_lc" 'comment|requirement|should|must|expected|meant for|supposed to|wrong|not right|instead of|copy' && flags+=("requirement-check")
  task_contains "$task_lc" 'visual|layout|spacing|color|typography|hover|animation|responsive|ui polish|css' && flags+=("visual")
  task_contains "$task_lc" 'pr|pull request|review comment|code review|ci' && flags+=("review")
  task_contains "$task_lc" 'new api|schema|contract|migration|dependency|cross-system|cross system|parallel' && flags+=("contract")
  task_contains "$task_lc" 'n8n|workflow' && flags+=("n8n")
  task_contains "$task_lc" 'ai|llm|rag|prompt|vector|agent|multimodal' && flags+=("ai")
  task_contains "$task_lc" 'production|incident|outage|safety|guard|security' && flags+=("production")
  stack_has "$stack_csv" "playwright" && flags+=("playwright")

  if [ "${#flags[@]}" -eq 0 ]; then
    printf 'none\n'
  else
    join_by "," "${flags[@]}"
    printf '\n'
  fi
}

requires_requirement_check() {
  local task_lc="$1"
  task_contains "$task_lc" 'comment|requirement|should|must|expected|meant for|supposed to|wrong|not right|instead of|acceptance criteria|issue|spec|copy'
}

is_generic_task() {
  local task_lc="$1"
  task_contains "$task_lc" 'review the app|review codebase|audit codebase|check for issues|find gaps|production readiness|framework gaps'
}

skill_exists() {
  local skill="$1"
  [ -f "$(framework_root)/skills/$skill/SKILL.md" ]
}

append_unique_csv() {
  local csv="$1"
  local value="$2"
  local item
  [ -n "$value" ] || {
    printf '%s\n' "$csv"
    return 0
  }
  IFS=',' read -r -a existing_items <<< "$csv"
  for item in "${existing_items[@]-}"; do
    item="$(printf '%s' "$item" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ "$item" = "$value" ] && {
      printf '%s\n' "$csv"
      return 0
    }
  done
  if [ -z "$csv" ]; then
    printf '%s\n' "$value"
  else
    printf '%s,%s\n' "$csv" "$value"
  fi
}

classify_task_shape() {
  local task_lc="$1"
  if task_contains "$task_lc" 'typo|copy change|text swap|rename|small config|single-file|single file|one file|mechanical|token swap'; then
    printf 'mechanical\n'
  elif task_contains "$task_lc" 'framework gap|production readiness|roadmap|design philosophy|long-term|migration|cross-system|cross system|orchestration'; then
    printf 'strategic\n'
  elif task_contains "$task_lc" 'review|audit|check|verify'; then
    printf 'review\n'
  else
    printf 'implementation\n'
  fi
}

scan_text_for_policy_violations() {
  local content="$1"
  local findings=""

  if printf '%s' "$content" | grep -Eq 'AKIA[0-9A-Z]{16}'; then
    findings="$(append_unique_csv "$findings" "hardcoded-aws-key")"
  fi
  if printf '%s' "$content" | grep -Eq 'sk-(proj|org|svcacct)-[A-Za-z0-9_-]{20,}'; then
    findings="$(append_unique_csv "$findings" "hardcoded-openai-key")"
  fi
  if printf '%s' "$content" | grep -Eq 'sk-ant-[A-Za-z0-9-]{20,}'; then
    findings="$(append_unique_csv "$findings" "hardcoded-anthropic-key")"
  fi
  if printf '%s' "$content" | grep -Eq 'AIza[0-9A-Za-z_-]{35}'; then
    findings="$(append_unique_csv "$findings" "hardcoded-google-key")"
  fi
  if printf '%s' "$content" | grep -Eqi '(password|pwd)[[:space:]]*[:=][[:space:]]*["'\''][^"'\'']{4,}["'\'']'; then
    findings="$(append_unique_csv "$findings" "inline-password")"
  fi
  if printf '%s' "$content" | grep -Eq 'https?://[^[:space:]/:@]+:[^[:space:]@]+@'; then
    findings="$(append_unique_csv "$findings" "embedded-url-credentials")"
  fi
  if printf '%s' "$content" | grep -Eqi 'co-authored-by:|generated by chatgpt|generated by claude|generated with ai'; then
    findings="$(append_unique_csv "$findings" "ai-attribution")"
  fi

  printf '%s\n' "${findings:-none}"
}

git_core_hooks_path() {
  git config --local --get core.hooksPath 2>/dev/null || true
}

ensure_project_git_hooks() {
  local root="${1:-$(project_root)}"
  local hooks_dir="$root/.githooks"
  mkdir -p "$hooks_dir"
}

detect_missing_deps() {
  local missing=""
  has_command codex || missing="$(append_unique_csv "$missing" "codex")"
  has_command rg || missing="$(append_unique_csv "$missing" "ripgrep")"
  has_command gh || missing="$(append_unique_csv "$missing" "gh")"
  has_command jq || missing="$(append_unique_csv "$missing" "jq")"
  printf '%s\n' "${missing:-none}"
}

cache_read() {
  local name="$1"
  local file
  file="$(project_cache_dir)/$name"
  [ -f "$file" ] || return 1
  cat "$file"
}

cache_write() {
  local name="$1"
  shift
  ensure_cache_dir
  printf '%s\n' "$*" > "$(project_cache_dir)/$name"
}

cached_stack_summary() {
  local cached
  cached="$(cache_read stack.txt 2>/dev/null || true)"
  if [ -n "$cached" ]; then
    printf '%s\n' "$cached"
  else
    cached="$(bash "$(framework_root)/scripts/detect-project-stack.sh" "$(project_root)")"
    cache_write stack.txt "$cached"
    printf '%s\n' "$cached"
  fi
}

cached_feature_summary() {
  local cached
  cached="$(cache_read features.txt 2>/dev/null || true)"
  if [ -n "$cached" ]; then
    printf '%s\n' "$cached"
  else
    cached="$(bash "$(framework_root)/scripts/detect-project-features.sh" "$(project_root)")"
    cache_write features.txt "$cached"
    printf '%s\n' "$cached"
  fi
}

cached_policy_summary() {
  local cached
  cached="$(cache_read policy.txt 2>/dev/null || true)"
  if [ -n "$cached" ]; then
    printf '%s\n' "$cached"
  else
    cached="$(bash "$(framework_root)/scripts/detect-project-policy.sh" "$(project_root)")"
    cache_write policy.txt "$cached"
    printf '%s\n' "$cached"
  fi
}

cached_convention_summary() {
  local cached
  cached="$(cache_read conventions.txt 2>/dev/null || true)"
  if [ -n "$cached" ]; then
    printf '%s\n' "$cached"
  else
    cached="$(bash "$(framework_root)/scripts/detect-project-conventions.sh" "$(project_root)")"
    cache_write conventions.txt "$cached"
    printf '%s\n' "$cached"
  fi
}

cached_repo_intelligence_file() {
  local file
  file="$(project_cache_dir)/repo-intelligence.env"
  if [ ! -f "$file" ] || repo_intelligence_stale "$file"; then
    bash "$(framework_root)/scripts/detect-repo-intelligence.sh" "$(project_root)" > "$file"
  fi
  printf '%s\n' "$file"
}

refresh_repo_intelligence() {
  local file
  file="$(project_cache_dir)/repo-intelligence.env"
  bash "$(framework_root)/scripts/detect-repo-intelligence.sh" "$(project_root)" > "$file"
  printf '%s\n' "$file"
}

repo_intelligence_stale() {
  local file="$1"
  local expected actual
  [ -f "$file" ] || return 0
  expected="$(repo_intelligence_fingerprint)"
  actual="$(sed -n 's/^RI_FINGERPRINT=//p' "$file" | tail -n 1)"
  actual="${actual#\'}"
  actual="${actual%\'}"
  [ -n "$actual" ] || return 0
  [ "$expected" != "$actual" ]
}

repo_intelligence_summary() {
  load_repo_intelligence
  printf 'framework=%s\n' "$RI_PRIMARY_FRAMEWORK"
  printf 'stack=%s\n' "$RI_STACK"
  printf 'features=%s\n' "$RI_FEATURES"
  printf 'policy=%s\n' "$RI_POLICY"
  printf 'domain_hints=%s\n' "$RI_DOMAIN_HINTS"
  printf 'refreshed_at=%s\n' "${RI_REFRESHED_AT:-unknown}"
  printf 'fingerprint=%s\n' "${RI_FINGERPRINT:-unknown}"
}

load_repo_intelligence() {
  local file
  file="$(cached_repo_intelligence_file)"
  # shellcheck disable=SC1090
  . "$file"
  : "${RI_STACK:=unknown}"
  : "${RI_FEATURES:=none}"
  : "${RI_POLICY:=none}"
  : "${RI_CONVENTIONS:=none}"
  : "${RI_PRIMARY_FRAMEWORK:=unknown}"
  : "${RI_FRONTEND_SYSTEM:=unknown}"
  : "${RI_BACKEND_SYSTEM:=unknown}"
  : "${RI_TEST_SYSTEM:=unknown}"
  : "${RI_DOMAIN_HINTS:=core}"
}

detect_task_intent() {
  local task_lc="$1"
  if task_contains "$task_lc" '(^|[^a-z])(review|audit|findings|comment)([^a-z]|$)|pr review|review comment'; then
    printf 'review\n'
  elif task_contains "$task_lc" 'test|coverage|regression|e2e'; then
    printf 'test\n'
  elif task_contains "$task_lc" 'refactor|simplify|migrate|clean up|modernize'; then
    printf 'refactor\n'
  elif task_contains "$task_lc" 'bug|fix|crash|wrong behavior|debug|incident|failure|performance'; then
    printf 'fix\n'
  elif task_contains "$task_lc" 'design|architecture|schema|contract|technical plan|dependency'; then
    printf 'design\n'
  elif task_contains "$task_lc" 'backlog|sprint|milestone|ticket|repo setup|create pr|open pr'; then
    printf 'manage\n'
  else
    printf 'implement\n'
  fi
}

choose_role_from_repo_intelligence() {
  local task_lc="$1"
  local shape="$2"
  local intent
  load_repo_intelligence
  intent="$(detect_task_intent "$task_lc")"

  if task_contains "$task_lc" 'framework health|new skill|role update|routing|codex framework|framework gap|production readiness|operating model|orchestration redesign|skill architecture|runtime guard'; then
    printf 'framework-manager\n'
    return 0
  fi
  if task_contains "$task_lc" 'dependency audit|security audit|cve|plugin review'; then
    printf 'auditor\n'
    return 0
  fi
  case "$intent" in
    manage) printf 'project-manager\n'; return 0 ;;
    review) printf 'reviewer\n'; return 0 ;;
    test) printf 'tester\n'; return 0 ;;
    refactor) printf 'refactorer\n'; return 0 ;;
    design) printf 'architect\n'; return 0 ;;
  esac

  if task_contains "$task_lc" 'react native|expo|flutter|ios|android|mobile'; then
    printf 'builder-mobile\n'
    return 0
  fi
  if task_contains "$task_lc" 'n8n|workflow node|workflow retry|webhook chain'; then
    printf 'builder-n8n\n'
    return 0
  fi
  if task_contains "$task_lc" ' llm|^llm| ai |^ai |rag|prompt|vector|agent|multimodal|chatbot'; then
    printf 'builder-ai\n'
    return 0
  fi
  if task_contains "$task_lc" 'automation|workflow'; then
    printf 'builder-automation\n'
    return 0
  fi
  if task_contains "$task_lc" 'docker|kubernetes|infra|deploy|ci|cd'; then
    printf 'builder-infra\n'
    return 0
  fi
  if { [ "$RI_PRIMARY_FRAMEWORK" = "nextjs" ] || [ "$RI_PRIMARY_FRAMEWORK" = "blazor" ]; } \
    && task_contains "$task_lc" 'route handler|server action|app router|razor|page and api|full-stack framework|full stack'; then
    printf 'builder-fullstack\n'
    return 0
  fi
  if printf '%s' "$RI_DOMAIN_HINTS" | grep -Eq '(^|,)mobile(,|$)'; then
    printf 'builder-mobile\n'
    return 0
  fi
  if task_contains "$task_lc" 'ui|component|page|frontend|styling|form|accessibility|avatar|image|hero|section|copy|landing'; then
    case "$intent" in
      fix) printf 'fixer\n' ;;
      *) printf 'builder-frontend\n' ;;
    esac
    return 0
  fi
  if task_contains "$task_lc" 'api|backend|service|auth|job|database|persistence|query|endpoint'; then
    case "$intent" in
      fix) printf 'fixer\n' ;;
      *) printf 'builder-backend\n' ;;
    esac
    return 0
  fi
  if [ "$RI_PRIMARY_FRAMEWORK" = "nextjs" ] || [ "$RI_PRIMARY_FRAMEWORK" = "react" ] || [ "$RI_PRIMARY_FRAMEWORK" = "vue" ] || [ "$RI_PRIMARY_FRAMEWORK" = "angular" ]; then
    case "$intent" in
      fix) printf 'fixer\n' ;;
      *) printf 'builder-frontend\n' ;;
    esac
    return 0
  fi
  if [ "$RI_BACKEND_SYSTEM" != "unknown" ]; then
    case "$intent" in
      fix) printf 'fixer\n' ;;
      *) printf 'builder-backend\n' ;;
    esac
    return 0
  fi
  printf 'builder\n'
}

choose_tier_from_role_and_task() {
  local role="$1"
  local task_lc="$2"
  local shape="$3"
  local tier="medium"
  [ "$shape" = "mechanical" ] && tier="low"
  case "$role" in
    framework-manager)
      if task_contains "$task_lc" 'framework gap|production readiness|operating model|orchestration redesign|skill architecture|runtime guard'; then
        tier="xhigh"
      else
        tier="high"
      fi
      ;;
    architect|builder-fullstack|builder-ai|builder-n8n|builder-automation|refactorer)
      tier="high"
      ;;
    project-manager)
      tier="low"
      ;;
    fixer)
      tier="medium"
      task_contains "$task_lc" 'across|cross-system|cross system|multi-system|multi service|migration|webhook|concurrency|deadlock|race condition|distributed' && tier="high"
      [ "$shape" = "mechanical" ] && tier="low"
      ;;
    reviewer|tester|builder-frontend|builder-backend|builder-infra|builder-mobile|builder|auditor)
      [ "$tier" = "low" ] || tier="medium"
      ;;
  esac
  printf '%s\n' "$tier"
}

infer_domains_for_task() {
  local role="$1"
  local task_lc="$2"
  local stack_csv="$3"
  local domains=""

  add_domain() {
    local domain="$1"
    domains="$(append_unique_csv "$domains" "$domain")"
  }

  case "$role" in
    builder-frontend|reviewer)
      if task_contains "$task_lc" 'ui|frontend|component|page|style|css|layout|accessibility|responsive|visual|avatar|image|hero|section|copy|text|landing'; then
        add_domain "frontend"
      fi
      if task_contains "$task_lc" 'api|backend|service|database|query|endpoint|auth'; then
        add_domain "backend"
      fi
      ;;
    builder-backend|architect|fixer|refactorer|builder)
      if task_contains "$task_lc" 'ui|frontend|component|page|style|css|layout|accessibility|responsive|visual|avatar|image|hero|section|copy|text|landing'; then
        add_domain "frontend"
      fi
      if task_contains "$task_lc" 'api|backend|service|database|query|endpoint|auth|migration|job'; then
        add_domain "backend"
      fi
      ;;
    builder-mobile)
      add_domain "mobile"
      ;;
    builder-infra)
      add_domain "infra"
      ;;
    builder-automation|builder-ai|builder-n8n|builder-fullstack)
      add_domain "specialized"
      ;;
    tester)
      add_domain "testing"
      ;;
    auditor|project-manager|framework-manager|estimator)
      add_domain "core"
      ;;
  esac

  stack_has "$stack_csv" "react" && add_domain "frontend"
  stack_has "$stack_csv" "vue" && add_domain "frontend"
  stack_has "$stack_csv" "angular" && add_domain "frontend"
  stack_has "$stack_csv" "nextjs" && add_domain "specialized"
  stack_has "$stack_csv" "dotnet" && add_domain "backend"
  stack_has "$stack_csv" "blazor" && add_domain "specialized"
  stack_has "$stack_csv" "flutter" && add_domain "mobile"
  stack_has "$stack_csv" "react-native" && add_domain "mobile"

  if [ -z "$domains" ]; then
    case "$role" in
      tester) domains="testing" ;;
      builder-infra) domains="infra" ;;
      builder-mobile) domains="mobile" ;;
      builder-automation|builder-ai|builder-n8n|builder-fullstack) domains="specialized" ;;
      builder-frontend) domains="frontend" ;;
      builder-backend|architect|builder)
        if task_contains "$task_lc" 'ui|frontend|component|page|style|css|layout|accessibility|responsive|visual|avatar|image|hero|section|copy|text|landing'; then
          domains="frontend"
        else
          domains="backend"
        fi
        ;;
      fixer|refactorer|reviewer)
        if task_contains "$task_lc" 'ui|frontend|component|page|style|css|layout|accessibility|responsive|visual|avatar|image|hero|section|copy|text|landing'; then
          domains="frontend"
        else
          domains="backend"
        fi
        ;;
      *) domains="core" ;;
    esac
  fi

  if [ "$domains" != "core" ]; then
    domains="$(append_unique_csv "$domains" "core")"
  fi

  printf '%s\n' "$domains"
}

skill_map_path() {
  local domain="$1"
  printf '%s/SKILLS_MAP.%s.md\n' "$(framework_root)" "$domain"
}

resolve_skills_from_map() {
  local map_file="$1"
  local task_lc="$2"
  [ -f "$map_file" ] || return 0
  awk -F'|' '
    /^\| `/ {
      skill=$2; keywords=$3
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", skill)
      gsub(/`/, "", skill)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", keywords)
      print skill "|" keywords
    }
  ' "$map_file" | while IFS='|' read -r skill keywords; do
    [ -n "$skill" ] || continue
    keyword_regex="$(printf '%s' "$keywords" | sed 's/, /|/g; s/,/|/g')"
    if printf '%s' "$task_lc" | grep -Eqi "$keyword_regex"; then
      printf '%s\n' "$skill"
    fi
  done
}

resolve_skills_for_domains() {
  local domains_csv="$1"
  local task_lc="$2"
  local domain skill resolved=""
  IFS=',' read -r -a domains_arr <<< "$domains_csv"
  for domain in "${domains_arr[@]}"; do
    domain="$(printf '%s' "$domain" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -n "$domain" ] || continue
    while IFS= read -r skill; do
      [ -n "$skill" ] || continue
      resolved="$(append_unique_csv "$resolved" "$skill")"
    done <<EOF
$(resolve_skills_from_map "$(skill_map_path "$domain")" "$task_lc")
EOF
  done
  printf '%s\n' "${resolved:-none}"
}

feature_to_skills() {
  local feature="$1"
  case "$feature" in
    dark-mode) printf 'dark-mode\n' ;;
    pwa) printf 'pwa-implementation\n' ;;
    i18n) printf 'i18n-implementation\n' ;;
    analytics) printf 'analytics-implementation\n' ;;
    error-tracking) printf 'error-tracking\n' ;;
    feature-flags) printf 'feature-flags\n' ;;
    background-jobs) printf 'background-jobs\n' ;;
    realtime) printf 'websocket-realtime\n' ;;
    search) printf 'search-implementation\n' ;;
    uploads) printf 'file-upload-storage\n' ;;
    email) printf 'email-notifications\n' ;;
    push) printf 'push-notifications\n' ;;
    offline-sync) printf 'offline-sync-design\n' ;;
    video) printf 'video-streaming\n' ;;
    caching) printf 'caching-strategy\n' ;;
    database-orm) printf 'database-optimization\n' ;;
    resilience) printf 'resilience-patterns\n' ;;
    stripe) printf 'payment-integration\nsaas-billing-portal\n' ;;
    auth) printf 'auth-security\nsaas-onboarding\n' ;;
    graphql) printf 'graphql-design\ngraphql-implement\n' ;;
    message-queue) printf 'message-queue-patterns\n' ;;
    observability) printf 'observability-design\n' ;;
    rate-limiting) printf 'rate-limiting\n' ;;
    firebase) printf 'firebase-patterns\n' ;;
    reporting) printf 'reporting-dashboards\n' ;;
    state-management) printf 'state-management\n' ;;
    forms) printf 'advanced-forms\n' ;;
    motion) printf 'animation-motion\n' ;;
    advanced-animation) printf 'advanced-animation\n' ;;
    design-system) printf 'design-system-implement\n' ;;
    tailwind) printf 'design-system-implement\nui-consistency-audit\nresponsive-design\n' ;;
    variants) printf 'design-system-implement\n' ;;
    ui-primitives) printf 'design-system-implement\nui-consistency-audit\n' ;;
  esac
}

resolve_feature_skills() {
  local features_csv="$1"
  local resolved="" feature skill
  IFS=',' read -r -a features_arr <<< "$features_csv"
  for feature in "${features_arr[@]}"; do
    feature="$(printf '%s' "$feature" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -n "$feature" ] || continue
    while IFS= read -r skill; do
      [ -n "$skill" ] || continue
      resolved="$(append_unique_csv "$resolved" "$skill")"
    done <<EOF
$(feature_to_skills "$feature")
EOF
  done
  printf '%s\n' "${resolved:-none}"
}

csv_contains() {
  local csv="$1"
  local value="$2"
  printf ',%s,' "$csv" | grep -q ",$value,"
}

resolve_domain_baseline_skills() {
  local role="$1"
  local domains_csv="$2"
  local resolved=""

  if csv_contains "$domains_csv" "frontend"; then
    case "$role" in
      builder-frontend|builder|builder-fullstack|fixer|refactorer|reviewer|architect)
        resolved="$(append_unique_csv "$resolved" "frontend-implement")"
        resolved="$(append_unique_csv "$resolved" "responsive-design")"
        resolved="$(append_unique_csv "$resolved" "design-system-implement")"
        resolved="$(append_unique_csv "$resolved" "animation-motion")"
        resolved="$(append_unique_csv "$resolved" "ui-consistency-audit")"
        ;;
    esac
    case "$role" in
      builder-frontend|builder|builder-fullstack|fixer|refactorer)
        resolved="$(append_unique_csv "$resolved" "accessibility-implement")"
        resolved="$(append_unique_csv "$resolved" "seo-optimization")"
        ;;
      reviewer|architect)
        resolved="$(append_unique_csv "$resolved" "accessibility-audit")"
        resolved="$(append_unique_csv "$resolved" "seo-audit")"
        resolved="$(append_unique_csv "$resolved" "ui-consistency-audit")"
        resolved="$(append_unique_csv "$resolved" "frontend-review")"
        ;;
      tester)
        resolved="$(append_unique_csv "$resolved" "frontend-test")"
        ;;
    esac
  fi

  if csv_contains "$domains_csv" "backend"; then
    case "$role" in
      builder-backend|builder|builder-fullstack|fixer|refactorer|reviewer|architect)
        resolved="$(append_unique_csv "$resolved" "backend-implement")"
        resolved="$(append_unique_csv "$resolved" "api-design")"
        resolved="$(append_unique_csv "$resolved" "data-validation-design")"
        resolved="$(append_unique_csv "$resolved" "auth-security")"
        resolved="$(append_unique_csv "$resolved" "database-optimization")"
        resolved="$(append_unique_csv "$resolved" "docs-sync")"
        resolved="$(append_unique_csv "$resolved" "observability-design")"
        ;;
      tester)
        resolved="$(append_unique_csv "$resolved" "backend-test")"
        ;;
      reviewer|architect)
        resolved="$(append_unique_csv "$resolved" "backend-review")"
        ;;
    esac
  fi

  if csv_contains "$domains_csv" "mobile"; then
    case "$role" in
      builder-mobile|fixer|refactorer|reviewer|architect)
        resolved="$(append_unique_csv "$resolved" "mobile-implement")"
        resolved="$(append_unique_csv "$resolved" "accessibility-implement")"
        resolved="$(append_unique_csv "$resolved" "animation-motion")"
        resolved="$(append_unique_csv "$resolved" "mobile-deployment")"
        resolved="$(append_unique_csv "$resolved" "deployment-validation")"
        resolved="$(append_unique_csv "$resolved" "offline-sync-design")"
        resolved="$(append_unique_csv "$resolved" "auth-security")"
        ;;
      tester)
        resolved="$(append_unique_csv "$resolved" "mobile-test")"
        ;;
      reviewer|architect)
        resolved="$(append_unique_csv "$resolved" "mobile-review")"
        resolved="$(append_unique_csv "$resolved" "accessibility-audit")"
        ;;
    esac
  fi

  if csv_contains "$domains_csv" "infra"; then
    resolved="$(append_unique_csv "$resolved" "devops-ci")"
    resolved="$(append_unique_csv "$resolved" "infrastructure-as-code")"
    resolved="$(append_unique_csv "$resolved" "deployment-validation")"
    case "$role" in
      builder-infra|architect|reviewer|fixer)
        resolved="$(append_unique_csv "$resolved" "deployment-strategies")"
        resolved="$(append_unique_csv "$resolved" "environment-management")"
        resolved="$(append_unique_csv "$resolved" "kubernetes-workload")"
        resolved="$(append_unique_csv "$resolved" "observability-design")"
        resolved="$(append_unique_csv "$resolved" "incident-response")"
        ;;
    esac
  fi

  if csv_contains "$domains_csv" "specialized"; then
    case "$role" in
      builder-ai)
        resolved="$(append_unique_csv "$resolved" "automation-ai-workflows")"
        resolved="$(append_unique_csv "$resolved" "llm-security")"
        resolved="$(append_unique_csv "$resolved" "ai-agent-architecture")"
        resolved="$(append_unique_csv "$resolved" "prompt-management")"
        resolved="$(append_unique_csv "$resolved" "rag-pipeline")"
        resolved="$(append_unique_csv "$resolved" "vector-database")"
        resolved="$(append_unique_csv "$resolved" "ai-streaming")"
        resolved="$(append_unique_csv "$resolved" "multimodal-processing")"
        ;;
      builder-n8n)
        resolved="$(append_unique_csv "$resolved" "automation-n8n-implement")"
        resolved="$(append_unique_csv "$resolved" "automation-n8n-architecture")"
        resolved="$(append_unique_csv "$resolved" "automation-n8n-debug")"
        resolved="$(append_unique_csv "$resolved" "n8n-test")"
        resolved="$(append_unique_csv "$resolved" "llm-security")"
        resolved="$(append_unique_csv "$resolved" "prompt-management")"
        ;;
      builder-automation)
        resolved="$(append_unique_csv "$resolved" "automation-ai-workflows")"
        resolved="$(append_unique_csv "$resolved" "llm-security")"
        resolved="$(append_unique_csv "$resolved" "automation-n8n-architecture")"
        resolved="$(append_unique_csv "$resolved" "automation-n8n-debug")"
        resolved="$(append_unique_csv "$resolved" "n8n-test")"
        resolved="$(append_unique_csv "$resolved" "prompt-management")"
        resolved="$(append_unique_csv "$resolved" "rag-pipeline")"
        resolved="$(append_unique_csv "$resolved" "vector-database")"
        ;;
      builder-fullstack)
        resolved="$(append_unique_csv "$resolved" "frontend-implement")"
        resolved="$(append_unique_csv "$resolved" "backend-implement")"
        resolved="$(append_unique_csv "$resolved" "api-design")"
        resolved="$(append_unique_csv "$resolved" "accessibility-implement")"
        resolved="$(append_unique_csv "$resolved" "data-validation-design")"
        resolved="$(append_unique_csv "$resolved" "docs-sync")"
        ;;
    esac
  fi

  if csv_contains "$domains_csv" "core"; then
    case "$role" in
      framework-manager)
        resolved="$(append_unique_csv "$resolved" "framework-management")"
        resolved="$(append_unique_csv "$resolved" "docs-sync")"
        ;;
      auditor)
        resolved="$(append_unique_csv "$resolved" "security-audit")"
        resolved="$(append_unique_csv "$resolved" "dependency-audit")"
        resolved="$(append_unique_csv "$resolved" "audit-logging")"
        resolved="$(append_unique_csv "$resolved" "incident-response")"
        ;;
      project-manager|estimator)
        resolved="$(append_unique_csv "$resolved" "process-hygiene")"
        resolved="$(append_unique_csv "$resolved" "project-setup")"
        resolved="$(append_unique_csv "$resolved" "release-management")"
        resolved="$(append_unique_csv "$resolved" "adr-management")"
        resolved="$(append_unique_csv "$resolved" "docs-sync")"
        ;;
      architect)
        resolved="$(append_unique_csv "$resolved" "adr-management")"
        resolved="$(append_unique_csv "$resolved" "security-audit")"
        resolved="$(append_unique_csv "$resolved" "observability-design")"
        ;;
    esac
  fi

  printf '%s\n' "${resolved:-none}"
}

resolve_stack_skills() {
  local role="$1"
  local stack_csv="$2"
  local resolved=""

  if stack_has "$stack_csv" "react"; then
    case "$role" in
      builder-frontend|builder|builder-fullstack|fixer|refactorer|reviewer|architect) resolved="$(append_unique_csv "$resolved" "frontend-implement-react")" ;;
      tester) resolved="$(append_unique_csv "$resolved" "frontend-test-react")" ;;
    esac
  fi
  if stack_has "$stack_csv" "vue"; then
    case "$role" in
      builder-frontend|builder|fixer|refactorer|reviewer|architect) resolved="$(append_unique_csv "$resolved" "frontend-implement-vue")" ;;
      tester) resolved="$(append_unique_csv "$resolved" "frontend-test-vue")" ;;
    esac
  fi
  if stack_has "$stack_csv" "angular"; then
    case "$role" in
      builder-frontend|builder|fixer|refactorer|reviewer|architect) resolved="$(append_unique_csv "$resolved" "frontend-implement-angular")" ;;
      tester) resolved="$(append_unique_csv "$resolved" "frontend-test-angular")" ;;
    esac
  fi
  if stack_has "$stack_csv" "nextjs"; then
    case "$role" in
      builder-fullstack|builder|architect|reviewer|builder-ai|builder-automation) resolved="$(append_unique_csv "$resolved" "fullstack-nextjs-implement")" ;;
      tester) resolved="$(append_unique_csv "$resolved" "fullstack-nextjs-test")" ;;
    esac
  fi
  if stack_has "$stack_csv" "tailwind"; then
    case "$role" in
      builder-frontend|builder|builder-fullstack|fixer|refactorer|reviewer|architect)
        resolved="$(append_unique_csv "$resolved" "design-system-implement")"
        resolved="$(append_unique_csv "$resolved" "ui-consistency-audit")"
        ;;
    esac
  fi
  if stack_has "$stack_csv" "dotnet"; then
    case "$role" in
      builder-backend|builder|builder-fullstack|architect|reviewer|fixer|refactorer) resolved="$(append_unique_csv "$resolved" "backend-implement-dotnet")" ;;
      tester) resolved="$(append_unique_csv "$resolved" "backend-test-dotnet")" ;;
    esac
  fi
  if stack_has "$stack_csv" "nestjs"; then
    case "$role" in
      builder-backend|builder|architect|reviewer|fixer|refactorer) resolved="$(append_unique_csv "$resolved" "backend-implement-nestjs")" ;;
      tester) resolved="$(append_unique_csv "$resolved" "backend-test-nestjs")" ;;
    esac
  fi
  if stack_has "$stack_csv" "typescript" && ! stack_has "$stack_csv" "nestjs" && ! stack_has "$stack_csv" "dotnet" && ! stack_has "$stack_csv" "nextjs"; then
    case "$role" in
      builder-backend|builder|architect|reviewer|fixer|refactorer) resolved="$(append_unique_csv "$resolved" "backend-implement-node")" ;;
      tester) resolved="$(append_unique_csv "$resolved" "backend-test-node")" ;;
    esac
  fi
  if stack_has "$stack_csv" "flutter"; then
    case "$role" in
      builder-mobile|fixer|refactorer|reviewer|architect) resolved="$(append_unique_csv "$resolved" "mobile-implement-flutter")" ;;
      tester) resolved="$(append_unique_csv "$resolved" "mobile-test-flutter")" ;;
    esac
  fi
  if stack_has "$stack_csv" "react-native"; then
    case "$role" in
      builder-mobile|fixer|refactorer|reviewer|architect) resolved="$(append_unique_csv "$resolved" "mobile-implement-reactnative")" ;;
      tester) resolved="$(append_unique_csv "$resolved" "mobile-test-reactnative")" ;;
    esac
  fi
  if stack_has "$stack_csv" "blazor"; then
    case "$role" in
      builder-fullstack|fixer|reviewer|architect) resolved="$(append_unique_csv "$resolved" "fullstack-blazor-implement")" ;;
      tester) resolved="$(append_unique_csv "$resolved" "fullstack-blazor-test")" ;;
    esac
  fi

  printf '%s\n' "${resolved:-none}"
}

merge_skill_csvs() {
  local merged="" csv item
  for csv in "$@"; do
    [ -n "$csv" ] || continue
    [ "$csv" = "none" ] && continue
    IFS=',' read -r -a items <<< "$csv"
    for item in "${items[@]}"; do
      item="$(printf '%s' "$item" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
      [ -n "$item" ] || continue
      skill_exists "$item" || continue
      merged="$(append_unique_csv "$merged" "$item")"
    done
  done
  printf '%s\n' "${merged:-none}"
}

csv_to_multiline() {
  local csv="$1" item
  [ "$csv" = "none" ] && return 0
  IFS=',' read -r -a items <<< "$csv"
  for item in "${items[@]}"; do
    item="$(printf '%s' "$item" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -n "$item" ] || continue
    printf '%s\n' "$item"
  done
}

model_fallback_chain() {
  case "$1" in
    codex-mini-latest) printf 'codex-mini-latest,gpt-5.4\n' ;;
    gpt-5.4) printf 'gpt-5.4,codex-mini-latest\n' ;;
    *) printf '%s\n' "$1" ;;
  esac
}
