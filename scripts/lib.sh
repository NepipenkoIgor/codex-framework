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
  local root hooks_dir
  root="$(project_root)"
  if git -C "$root" rev-parse --show-toplevel >/dev/null 2>&1; then
    hooks_dir="$(
      cd "$root"
      common_dir="$(git rev-parse --git-common-dir)"
      mkdir -p "$common_dir/hooks"
      cd "$common_dir/hooks"
      pwd
    )"
    printf '%s\n' "$hooks_dir"
  else
    printf '%s/.git/hooks\n' "$root"
  fi
}

project_commands_file() {
  printf '%s/project.env\n' "$(project_codex_dir)"
}

project_cache_dir() {
  local preferred scratch project_name probe
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
  scratch="/tmp/ai-codex-framework/$project_name/cache"
  mkdir -p "$scratch"
  printf '%s\n' "$scratch"
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

run_with_spinner() {
  local label="$1"
  shift
  local output_file status pid spinner i
  output_file="$(mktemp)"
  spinner='|/-\'
  i=0
  "$@" >"$output_file" 2>&1 &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    printf '\r[%s] %s %s' "$(date +%H:%M:%S)" "$label" "${spinner:i:1}" >&2
    i=$(( (i + 1) % 4 ))
    sleep 1
  done
  wait "$pid"
  status=$?
  printf '\r\033[K' >&2
  cat "$output_file"
  rm -f "$output_file"
  return "$status"
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
    builder|builder-frontend|builder-backend|builder-infra|builder-mobile|builder-fullstack|builder-automation|builder-ai|builder-n8n) echo "🟢" ;;
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

model_alias() {
  printf '%s\n' "$1" | sed -E 's/^gpt-//'
}

route_badge() {
  local role="$1"
  local model="$2"
  local tier="$3"
  printf '%s-%s-%s\n' "$(role_alias "$role")" "$(model_alias "$model")" "$(model_tag "$tier")"
}

codex_low_model() {
  printf '%s\n' "${CODEX_LOW_MODEL:-gpt-5.4-mini}"
}

codex_medium_model() {
  printf '%s\n' "${CODEX_MEDIUM_MODEL:-gpt-5.5}"
}

codex_high_model() {
  printf '%s\n' "${CODEX_HIGH_MODEL:-gpt-5.5}"
}

codex_xhigh_model() {
  printf '%s\n' "${CODEX_XHIGH_MODEL:-gpt-5.5}"
}

tier_model() {
  case "$1" in
    low) codex_low_model ;;
    medium) codex_medium_model ;;
    high) codex_high_model ;;
    xhigh) codex_xhigh_model ;;
    *) codex_medium_model ;;
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

codex_wait_for_go() {
  case "${CODEX_WAIT_FOR_GO:-0}" in
    1|true|TRUE|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

codex_wait_for_go_override_is_set() {
  [ "${CODEX_WAIT_FOR_GO+x}" = "x" ]
}

codex_should_wait_for_go() {
  local role="${1:-}"
  local tier="${2:-medium}"
  local task_shape="${3:-implementation}"
  local task_flags="${4:-none}"
  local task_text_lc
  task_text_lc="$(printf '%s' "${5:-}" | tr '[:upper:]' '[:lower:]')"

  if codex_wait_for_go_override_is_set; then
    codex_wait_for_go
    return $?
  fi

  case "$tier" in
    high|xhigh) return 0 ;;
    low) return 1 ;;
  esac

  case "$task_shape" in
    mechanical) return 1 ;;
    strategic) return 0 ;;
  esac

  if printf ',%s,' "$task_flags" | grep -Eq ',(contract|production|spec-driven|requirement-check),'; then
    return 0
  fi

  case "$role" in
    architect|framework-manager|refactorer) return 0 ;;
  esac

  if task_contains "$task_text_lc" 'migration|schema|contract|cross-system|cross system|multi-system|multi service|webhook|concurrency|deadlock|race condition|distributed|production|incident|outage|security'; then
    return 0
  fi

  return 1
}

codex_auto_submit() {
  case "${CODEX_AUTO_SUBMIT:-1}" in
    0|false|FALSE|no|NO) return 1 ;;
    *) return 0 ;;
  esac
}

codex_memory_auto_record() {
  case "${CODEX_MEMORY_AUTO_RECORD:-1}" in
    0|false|FALSE|no|NO) return 1 ;;
    *) return 0 ;;
  esac
}

csv_from_lines() {
  awk 'NF { gsub(/^[[:space:]]+|[[:space:]]+$/, ""); if ($0 != "") { if (out != "") out = out ","; out = out $0 } } END { print out }'
}

record_memory_episode() {
  local task="$1"
  local summary="${2:-Session completed.}"
  local tags="${3:-session}"
  local files

  codex_memory_auto_record || return 0
  [ -n "$task" ] || return 0

  files="$(git_changed_files 2>/dev/null | head -n 20 | csv_from_lines || true)"
  bash "$(framework_root)/scripts/memory-state.sh" add-episode \
    --task "$task" \
    --summary "$summary" \
    --files "$files" \
    --tags "$tags" >/dev/null 2>&1 || true
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

plain_skill_list() {
  local raw="$1"
  local skill
  [ -n "$raw" ] && [ "$raw" != "none" ] || return 0
  printf '%s\n' "$raw" | tr ',' '\n' | while IFS= read -r skill; do
    skill="$(printf '%s' "$skill" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ -n "$skill" ] || continue
    printf '%s\n' "$skill"
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
    {
      git diff --name-only HEAD
      git ls-files --others --exclude-standard
    } | awk 'NF && !seen[$0]++'
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

memory_root() {
  local preferred old_store scratch project_name probe
  if [ -n "${CODEX_MEMORY_DIR:-}" ]; then
    if mkdir -p "$CODEX_MEMORY_DIR" >/dev/null 2>&1; then
      probe="$CODEX_MEMORY_DIR/.write-test.$$"
      if touch "$probe" >/dev/null 2>&1; then
        rm -f "$probe"
        printf '%s\n' "$CODEX_MEMORY_DIR"
        return 0
      fi
    fi
  fi

  preferred="$(project_root)/.codex-memory"
  if mkdir -p "$preferred" >/dev/null 2>&1; then
    probe="$preferred/.write-test.$$"
    if touch "$probe" >/dev/null 2>&1; then
      rm -f "$probe"
      printf '%s\n' "$preferred"
      return 0
    fi
  fi

  old_store="$(project_codex_dir)/memory"
  if mkdir -p "$old_store" >/dev/null 2>&1; then
    probe="$old_store/.write-test.$$"
    if touch "$probe" >/dev/null 2>&1; then
      rm -f "$probe"
      printf '%s\n' "$old_store"
      return 0
    fi
  fi

  project_name="$(basename "$(project_root)")"
  scratch="/tmp/ai-codex-framework/$project_name/memory"
  mkdir -p "$scratch"
  printf '%s\n' "$scratch"
}

ensure_memory_root() {
  mkdir -p "$(memory_root)"
}

run_root() {
  local preferred scratch project_name probe
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
  scratch="/tmp/ai-codex-framework/$project_name/runs"
  mkdir -p "$scratch"
  printf '%s\n' "$scratch"
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


. "$(framework_root)/scripts/lib/repo-detection.sh"
. "$(framework_root)/scripts/lib/routing-skills.sh"
. "$(framework_root)/scripts/lib/git-flow.sh"
