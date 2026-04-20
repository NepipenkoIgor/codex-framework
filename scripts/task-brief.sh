#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

usage() {
  cat <<EOF
usage: task-brief.sh --task "<task text>" [--spec <spec-file>] [--output <file>]
EOF
}

TASK=""
SPEC_FILE=""
OUTPUT_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --task)
      TASK="${2:-}"
      shift 2
      ;;
    --spec)
      SPEC_FILE="${2:-}"
      shift 2
      ;;
    --output)
      OUTPUT_FILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

[ -n "$TASK" ] || fail "missing --task"

ROOT="$(project_root)"
FRAMEWORK_ROOT="$(framework_root)"
ensure_project_bootstrap "$ROOT"
load_project_commands
ensure_run_root
capabilities_report="$(bash "$FRAMEWORK_ROOT/scripts/capabilities.sh" "$ROOT" 2>/dev/null || true)"

decision="$(bash "$FRAMEWORK_ROOT/scripts/codex-fw.sh" route "$TASK")"
role="$(printf '%s\n' "$decision" | sed -n 's/.*role=\([^ ]*\).*/\1/p')"
model="$(printf '%s\n' "$decision" | sed -n 's/.*model=\([^ ]*\).*/\1/p')"
reasoning="$(printf '%s\n' "$decision" | sed -n 's/.*reasoning=\([^ ]*\).*/\1/p')"
stack="$(bash "$FRAMEWORK_ROOT/scripts/detect-project-stack.sh" "$ROOT")"
task_lc="$(printf '%s' "$TASK" | tr '[:upper:]' '[:lower:]')"

if [ -z "$SPEC_FILE" ]; then
  SPEC_FILE="$(active_spec_file || true)"
fi

skills=()

add_skill() {
  local skill="$1"
  local existing
  [ -n "$skill" ] || return 0
  for existing in ${skills[*]-}; do
    [ "$existing" = "$skill" ] && return 0
  done
  if [ -f "$FRAMEWORK_ROOT/skills/$skill/SKILL.md" ]; then
    skills+=("$skill")
  fi
}

has_stack() {
  printf ',%s,' "$stack" | grep -q ",$1,"
}

task_matches() {
  printf '%s' "$task_lc" | grep -Eq "$1"
}

package_runner="${PACKAGE_RUNNER:-none}"
package_exec="${PACKAGE_EXEC:-none}"
if [ "$package_runner" = "none" ] && { [ -f "$ROOT/bun.lockb" ] || [ -f "$ROOT/bun.lock" ]; }; then
  package_runner="bun run"
  package_exec="bunx"
elif [ "$package_runner" = "none" ] && [ -f "$ROOT/pnpm-lock.yaml" ]; then
  package_runner="pnpm"
  package_exec="pnpm exec"
elif [ "$package_runner" = "none" ] && [ -f "$ROOT/yarn.lock" ]; then
  package_runner="yarn"
  package_exec="yarn"
elif [ "$package_runner" = "none" ] && { [ -f "$ROOT/package-lock.json" ] || [ -f "$ROOT/package.json" ]; }; then
  package_runner="npm run"
  package_exec="npx"
fi

case "$role" in
  architect)
    add_skill "api-design"
    if task_matches 'ui|frontend|component|page|form|accessibility'; then
      add_skill "frontend-architecture"
    fi
    if task_matches 'api|backend|service|job|database|auth|schema|integration'; then
      add_skill "backend-architecture"
    fi
    [ -n "${skills[*]-}" ] || add_skill "backend-architecture"
    ;;
  builder)
    add_skill "frontend-implement"
    add_skill "backend-implement"
    ;;
  builder-frontend)
    add_skill "frontend-implement"
    add_skill "accessibility-implement"
    ;;
  builder-backend)
    add_skill "backend-implement"
    add_skill "api-design"
    ;;
  builder-infra)
    add_skill "devops-ci"
    add_skill "infrastructure-as-code"
    add_skill "deployment-validation"
    ;;
  builder-mobile)
    add_skill "mobile-implement"
    add_skill "accessibility-implement"
    ;;
  builder-fullstack)
    add_skill "frontend-implement"
    add_skill "backend-implement"
    add_skill "api-design"
    ;;
  builder-automation)
    add_skill "automation-ai-workflows"
    add_skill "llm-security"
    add_skill "prompt-engineering"
    ;;
  fixer)
    if task_matches 'ui|frontend|component|page|form|style|css'; then
      add_skill "frontend-debug"
    fi
    if task_matches 'api|backend|service|database|auth|job|integration|query'; then
      add_skill "backend-debug"
    fi
    [ -n "${skills[*]-}" ] || add_skill "backend-debug"
    ;;
  refactorer)
    if task_matches 'ui|frontend|component|page|form|style|css'; then
      add_skill "frontend-refactor"
    fi
    if task_matches 'api|backend|service|database|auth|job|integration|query'; then
      add_skill "backend-refactor"
    fi
    [ -n "${skills[*]-}" ] || add_skill "backend-refactor"
    ;;
  reviewer)
    domain_review=false
    if task_matches 'ui|frontend|component|page|form|style|css'; then
      add_skill "frontend-review"
      add_skill "ui-consistency-audit"
      domain_review=true
    fi
    if task_matches 'api|backend|service|database|auth|job|integration|query'; then
      add_skill "backend-review"
      add_skill "performance"
      domain_review=true
    fi
    if task_matches 'github|pull request|pr|review comment'; then
      add_skill "pr-review"
    fi
    add_skill "security-audit"
    [ "$domain_review" = true ] || add_skill "backend-review"
    ;;
  tester)
    if task_matches 'ui|frontend|component|page|form|style|css'; then
      add_skill "frontend-test"
    fi
    if task_matches 'api|backend|service|database|auth|job|integration|query'; then
      add_skill "backend-test"
    fi
    [ -n "${skills[*]-}" ] || add_skill "backend-test"
    ;;
  project-manager)
    add_skill "project-setup"
    add_skill "process-hygiene"
    ;;
  estimator)
    add_skill "spec"
    add_skill "process-hygiene"
    ;;
  auditor)
    add_skill "security-audit"
    add_skill "dependency-audit"
    add_skill "plugin-security-review"
    ;;
  framework-manager)
    add_skill "framework-management"
    ;;
esac

if has_stack react; then
  case "$role" in
    builder-frontend|builder|builder-fullstack|fixer|refactorer|reviewer|architect)
      add_skill "frontend-implement-react"
      ;;
    tester)
      add_skill "frontend-test-react"
      ;;
  esac
fi

if has_stack vue; then
  case "$role" in
    builder-frontend|builder|fixer|refactorer|reviewer|architect)
      add_skill "frontend-implement-vue"
      ;;
    tester)
      add_skill "frontend-test-vue"
      ;;
  esac
fi

if has_stack angular; then
  case "$role" in
    builder-frontend|builder|fixer|refactorer|reviewer|architect)
      add_skill "frontend-implement-angular"
      ;;
    tester)
      add_skill "frontend-test-angular"
      ;;
  esac
fi

if has_stack nextjs; then
  case "$role" in
    builder-fullstack|builder|architect|reviewer)
      add_skill "fullstack-nextjs-implement"
      ;;
    tester)
      add_skill "fullstack-nextjs-test"
      ;;
  esac
fi

if has_stack dotnet; then
  case "$role" in
    builder-backend|builder|builder-fullstack|architect|reviewer|fixer|refactorer)
      add_skill "backend-implement-dotnet"
      ;;
    tester)
      add_skill "backend-test-dotnet"
      ;;
  esac
fi

if has_stack nestjs; then
  case "$role" in
    builder-backend|builder|architect|reviewer|fixer|refactorer)
      add_skill "backend-implement-nestjs"
      ;;
    tester)
      add_skill "backend-test-nestjs"
      ;;
  esac
fi

if has_stack typescript && ! has_stack nestjs && ! has_stack dotnet && ! has_stack nextjs; then
  case "$role" in
    builder-backend|builder|architect|reviewer|fixer|refactorer)
      add_skill "backend-implement-node"
      ;;
    tester)
      add_skill "backend-test-node"
      ;;
  esac
fi

if has_stack flutter; then
  case "$role" in
    builder-mobile|fixer|refactorer|reviewer)
      add_skill "mobile-implement-flutter"
      ;;
    tester)
      add_skill "mobile-test-flutter"
      ;;
  esac
fi

if has_stack react-native; then
  case "$role" in
    builder-mobile|fixer|refactorer|reviewer)
      add_skill "mobile-implement-reactnative"
      ;;
    tester)
      add_skill "mobile-test-reactnative"
      ;;
  esac
fi

has_stack stripe && add_skill "payment-integration"
has_stack supabase && add_skill "supabase-patterns"
has_stack firebase && add_skill "firebase-patterns"
has_stack playwright && add_skill "e2e-test"

task_matches 'auth|session|oauth|jwt|passkey' && add_skill "auth-security"
task_matches 'form|validation|wizard' && add_skill "advanced-forms"
task_matches 'realtime|websocket|socket|sse' && add_skill "websocket-realtime"
task_matches 'search|index|query suggestions' && add_skill "search-implementation"
task_matches 'upload|storage|file|image' && add_skill "file-upload-storage"
task_matches 'queue|job|worker|cron' && add_skill "background-jobs"
task_matches 'cache|redis' && add_skill "caching-strategy"
task_matches 'design system|component library|storybook|tokens' && add_skill "design-system-implement"
task_matches 'seo|metadata|sitemap|open graph' && add_skill "seo-optimization"
task_matches 'i18n|locale|translation|rtl' && add_skill "i18n-implementation"
task_matches 'analytics|tracking|events' && add_skill "analytics-implementation"
task_matches 'observability|tracing|metrics|logging' && add_skill "observability-design"
task_matches 'rag|retrieval|embedding|vector' && add_skill "rag-pipeline"
task_matches 'rag|retrieval|embedding|vector' && add_skill "vector-database"
task_matches 'stream|sse' && add_skill "ai-streaming"
task_matches 'n8n|workflow' && add_skill "automation-n8n-implement"
task_matches 'n8n|workflow' && add_skill "automation-n8n-architecture"
task_matches 'gdpr|privacy|retention|consent' && add_skill "gdpr-compliance"
task_matches 'github|pull request|pr|review comment' && add_skill "ci-status"

if [ -f "$SPEC_FILE" ]; then
  read -r done_count failed_count pending_count <<EOF
$(spec_counts "$SPEC_FILE")
EOF
  spec_status="done=$done_count failed=$failed_count pending=$pending_count"
else
  spec_status="none"
fi

if git rev-parse --show-toplevel >/dev/null 2>&1; then
  scope_summary="$(git diff --stat HEAD 2>/dev/null || true)"
else
  scope_summary=""
fi

primary_skill="${skills[0]-none}"
supporting_skills=""
if [ -n "${skills[1]-}" ]; then
  supporting_skills="$(printf '%s\n' "${skills[@]:1}" | paste -sd ',' - | sed 's/,/, /g')"
fi

verification=()
[ -n "${TEST_CMD:-}" ] && verification+=("test: $TEST_CMD")
[ -n "${LINT_CMD:-}" ] && verification+=("lint: $LINT_CMD")
[ -n "${BUILD_CMD:-}" ] && verification+=("build: $BUILD_CMD")
if printf '%s' "$stack" | grep -Eq '(react|nextjs|vue|angular|playwright|blazor)'; then
  verification+=("browser/spec verification when UI-visible behavior changes")
fi
[ "${#verification[@]}" -gt 0 ] || verification+=("manual targeted verification")

github_preferred="not relevant"
github_fallback="not relevant"
github_local="not relevant"
if task_matches 'github|pull request|pr|issue|review|comment'; then
  if printf '%s\n' "$capabilities_report" | grep -q 'github_structured=yes'; then
    github_preferred="structured GitHub tools"
    if printf '%s\n' "$capabilities_report" | grep -q 'github_cli=yes' && printf '%s\n' "$capabilities_report" | grep -q 'github_auth_ready=yes'; then
      github_fallback="gh CLI"
    else
      github_fallback="local git only"
    fi
    github_local="local git only"
  elif printf '%s\n' "$capabilities_report" | grep -q 'github_cli=yes' && printf '%s\n' "$capabilities_report" | grep -q 'github_auth_ready=yes'; then
    github_preferred="gh CLI"
    github_fallback="local git only"
    github_local="local git only"
  elif git rev-parse --show-toplevel >/dev/null 2>&1; then
    github_preferred="local git only"
    github_fallback="none"
    github_local="local git only"
  else
    github_preferred="none"
    github_fallback="none"
    github_local="none"
  fi
fi

if [ -z "$OUTPUT_FILE" ]; then
  OUTPUT_FILE="$(run_root)/$(date -u +"%Y%m%dT%H%M%SZ")-brief.md"
fi

cat > "$OUTPUT_FILE" <<EOF
## Goal
$TASK

## Route
- Role: $role
- Model: $model
- Reasoning: $reasoning

## Stack
- Detected: $stack
- Framework signals: read CODEX.md and CODEX.skills.md first

## Scope
$(if [ -n "$scope_summary" ]; then printf '%s\n' "$scope_summary"; else echo "No current git diff summary available."; fi)

## Commands
- Package runner: $package_runner
- Direct local binaries: $package_exec
- Test: ${TEST_CMD:-}
- Lint: ${LINT_CMD:-}
- Build: ${BUILD_CMD:-}
- Dev: ${DEV_CMD:-}

## Capabilities
$(if [ -n "$capabilities_report" ]; then printf '%s\n' "$capabilities_report"; else echo "- unavailable"; fi)

## GitHub
- Preferred: $github_preferred
- Fallback: $github_fallback
- Local fallback: $github_local

## Constraints
- Respect existing project patterns.
- Do not revert unrelated changes.
- Keep the implementation narrow.
- For JS/TS repos, prefer the detected package runner and local binary executor above for direct commands.
- Update specs when the task is spec-driven.

## Skills
- Primary: $primary_skill
- Supporting: ${supporting_skills:-none}

## Spec
- Path: ${SPEC_FILE:-none}
- Status: $spec_status

## Verification
$(printf -- '- %s\n' "${verification[@]}")

## Closeout Style
- Prefer a short prose handoff over Summary / Verification / Notes headings.
- Start with what changed and why in one compact paragraph.
- Keep verification compact and concrete.
- Mention blockers or residual risk only if they matter.
- Sound like a teammate, not a generated changelog.

## Output Contract
- Status: done | partial | blocked
- Changed: [file paths]
- Notes: [blockers or non-obvious decisions only]
EOF

printf '%s\n' "$OUTPUT_FILE"
