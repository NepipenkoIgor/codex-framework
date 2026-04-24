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
refresh_repo_intelligence >/dev/null
load_repo_intelligence
ensure_run_root
ensure_cache_dir

if [ -z "$SPEC_FILE" ]; then
  SPEC_FILE="$(active_spec_file || true)"
fi

decision="$(bash "$FRAMEWORK_ROOT/scripts/codex-fw.sh" route "$TASK")"
role="$(printf '%s\n' "$decision" | sed -n 's/.*role=\([^ ]*\).*/\1/p')"
model="$(printf '%s\n' "$decision" | sed -n 's/.*model=\([^ ]*\).*/\1/p')"
reasoning="$(printf '%s\n' "$decision" | sed -n 's/.*reasoning=\([^ ]*\).*/\1/p')"
task_lc="$(printf '%s' "$TASK" | tr '[:upper:]' '[:lower:]')"
stack="$RI_STACK"
features="$RI_FEATURES"
policy="$RI_POLICY"
conventions="$RI_CONVENTIONS"
domains="$(infer_domains_for_task "$role" "$task_lc" "$stack")"
cache_write domains.txt "$domains"
task_flags="$(detect_task_flags "$task_lc" "$stack")"
task_shape="$(classify_task_shape "$task_lc")"
requirement_check="no"
requires_requirement_check "$task_lc" && requirement_check="yes"
capabilities_report="$(bash "$FRAMEWORK_ROOT/scripts/capabilities.sh" "$ROOT" 2>/dev/null || true)"

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

baseline_skills="$(resolve_domain_baseline_skills "$role" "$domains")"
stack_skills="$(resolve_stack_skills "$role" "$stack")"
map_skills="$(resolve_skills_for_domains "$domains" "$task_lc")"
feature_skills="$(resolve_feature_skills "$features")"
task_extra_skills="none"

task_contains "$task_lc" 'new api|endpoint|request boundary|schema change' && task_extra_skills="$(merge_skill_csvs "$task_extra_skills" "api-design,data-validation-design,audit-logging")"
task_contains "$task_lc" 'review|audit' && task_extra_skills="$(merge_skill_csvs "$task_extra_skills" "security-audit")"
task_contains "$task_lc" 'review' && csv_contains "$domains" "frontend" && task_extra_skills="$(merge_skill_csvs "$task_extra_skills" "ui-consistency-audit,accessibility-audit")"
task_contains "$task_lc" 'review' && csv_contains "$domains" "backend" && task_extra_skills="$(merge_skill_csvs "$task_extra_skills" "backend-review,performance")"
task_contains "$task_lc" 'debug|bug|fix|crash' && csv_contains "$domains" "frontend" && task_extra_skills="$(merge_skill_csvs "$task_extra_skills" "frontend-debug")"
task_contains "$task_lc" 'debug|bug|fix|crash' && csv_contains "$domains" "backend" && task_extra_skills="$(merge_skill_csvs "$task_extra_skills" "backend-debug")"
task_contains "$task_lc" 'debug|bug|fix|crash' && csv_contains "$domains" "mobile" && task_extra_skills="$(merge_skill_csvs "$task_extra_skills" "mobile-debug")"
task_contains "$task_lc" 'ui|frontend|component|page|style|css|layout|accessibility|responsive|visual|avatar|image|hero|section|copy|text|landing' && task_extra_skills="$(merge_skill_csvs "$task_extra_skills" "ui-consistency-audit,design-system-implement,responsive-design")"
task_contains "$task_lc" 'test|coverage|regression|e2e' && task_extra_skills="$(merge_skill_csvs "$task_extra_skills" "e2e-test")"
task_contains "$task_lc" 'docs|readme|swagger|openapi' && task_extra_skills="$(merge_skill_csvs "$task_extra_skills" "docs-sync")"
task_contains "$task_lc" 'performance|slow|latency' && task_extra_skills="$(merge_skill_csvs "$task_extra_skills" "performance")"
task_contains "$task_lc" 'n8n' && task_extra_skills="$(merge_skill_csvs "$task_extra_skills" "automation-n8n-debug")"
task_contains "$task_lc" 'chatbot|conversation|assistant ui' && task_extra_skills="$(merge_skill_csvs "$task_extra_skills" "chatbot-implement")"

resolved_skills="$(merge_skill_csvs "$baseline_skills" "$stack_skills" "$feature_skills" "$map_skills" "$task_extra_skills")"

if [ "$task_shape" = "mechanical" ]; then
  case "$role" in
    builder|builder-frontend|builder-backend|fixer|reviewer|tester|refactorer)
      resolved_skills="$(merge_skill_csvs "$baseline_skills")"
      ;;
  esac
fi

primary_skill="none"
supporting_skills="none"
if [ "$resolved_skills" != "none" ]; then
  primary_skill="$(printf '%s\n' "$resolved_skills" | cut -d',' -f1)"
  supporting_skills="$(printf '%s\n' "$resolved_skills" | cut -d',' -f2- | sed 's/^,//')"
  [ -n "$supporting_skills" ] || supporting_skills="none"
fi

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

execution_pattern="implement-standard"
contract_required="no"
if [ "$requirement_check" = "yes" ]; then
  execution_pattern="review-first"
elif task_contains "$task_lc" 'visual|layout|spacing|color|typography|hover|animation|responsive|ui polish|css'; then
  execution_pattern="review-first"
elif task_contains "$task_lc" 'new api|schema|contract|migration|dependency|cross-system|cross system|parallel'; then
  execution_pattern="contract-first"
  contract_required="yes"
elif [ "$task_shape" = "mechanical" ]; then
  execution_pattern="fast-path"
fi

handoff_id="none"
if [ "$contract_required" = "yes" ] || task_contains "$task_lc" 'parallel|handoff|sub-agent|subagent'; then
  handoff_id="$(date -u +"handoff-%Y%m%dT%H%M%SZ")"
  bash "$FRAMEWORK_ROOT/scripts/handoff-state.sh" init "$handoff_id" >/dev/null 2>&1 || true
fi

retry_chain="$(model_fallback_chain "$model")"

verification=()
[ -n "${TEST_CMD:-}" ] && verification+=("test: $TEST_CMD")
[ -n "${LINT_CMD:-}" ] && verification+=("lint: $LINT_CMD")
[ -n "${BUILD_CMD:-}" ] && verification+=("build: $BUILD_CMD")
task_contains "$task_lc" 'review|audit' && verification+=("findings-first review output")
[ "$requirement_check" = "yes" ] && verification+=("requirement check completed before edits")
if printf '%s' "$stack" | grep -Eq '(react|nextjs|vue|angular|playwright|blazor)'; then
  verification+=("browser/spec verification when UI-visible behavior changes")
fi
[ "${#verification[@]}" -gt 0 ] || verification+=("manual targeted verification")

github_preferred="not relevant"
github_fallback="not relevant"
github_local="not relevant"
if task_contains "$task_lc" 'github|pull request|pr|issue|review|comment'; then
  if printf '%s\n' "$capabilities_report" | grep -q 'github_structured=yes'; then
    github_preferred="structured GitHub tools"
    github_fallback="gh CLI"
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
- Retry chain: $retry_chain

## Stack
- Detected: $stack
- Features: $features
- Repo policy: $policy
- Domains: $domains
- Framework signals: read CODEX.md, CODEX.concepts.md, ORCHESTRATOR_REFERENCE.md, and CODEX.skills.md first
- Task flags: $task_flags
- Task shape: $task_shape

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

## Repo Conventions
$(if [ -n "$conventions" ]; then printf '%s\n' "$conventions"; else echo "none"; fi)

## GitHub
- Preferred: $github_preferred
- Fallback: $github_fallback
- Local fallback: $github_local

## Constraints
- Respect existing project patterns.
- Do not revert unrelated changes.
- Keep the implementation narrow.
- Treat skills as lazy context: identify names first, load bodies only when executing work.
- Prefer domain maps over ad hoc skill guesses.
- For JS/TS repos, prefer the detected package runner and local binary executor above for direct commands.
- Update specs when the task is spec-driven.
- Run guard scans before close-out for code or config changes.
- Use a contract-first approach when the task crosses API, schema, or parallel ownership boundaries.
- For requirement-sensitive tasks, do not edit first. Restate the requirement, compare current behavior to that requirement, identify the mismatch, and only then implement the correction.
- If the user is asking for judgment or correction, lead with the mismatch before proposing or applying edits.
- If repo policy includes tailwind-first or avoid-inline-styles, prefer utility classes and existing tokens/components over inline style objects.
- Read nearby files and shared UI primitives before introducing a new styling pattern.
- Prefer existing helpers, shared components, and established file-layer boundaries over new one-off abstractions.
- If repo conventions mention use-zod-validation, use-cn-helper, use-cva-variants, or shared test helpers, follow them instead of inventing a parallel pattern.

## Skills
- Primary: $primary_skill
- Supporting: $supporting_skills
- Resolution path: domain baseline -> stack -> features -> maps -> task extras

## Spec
- Path: ${SPEC_FILE:-none}
- Status: $spec_status

## Requirement Check
- Required: $requirement_check
- Before edits, produce:
  - Requirement: the intended behavior from the user, spec, or comment
  - Current behavior: what the code or current change actually does
  - Mismatch: why that behavior does not satisfy the requirement
  - Fix intent: the smallest correction that closes the gap
- If requirement evidence is ambiguous, stop and resolve that ambiguity before editing.

## Coordination
- Execution pattern: $execution_pattern
- Contract required: $contract_required
- Handoff state: $handoff_id

## Verification
$(printf -- '- %s\n' "${verification[@]}")
- guard: bash $FRAMEWORK_ROOT/scripts/guard-scan.sh --changed
- quality: bash $FRAMEWORK_ROOT/scripts/quality-check.sh --changed

## Output Contract
- Status: done | partial | blocked
- Requirement: [restated requirement or \`not required\`]
- Current behavior: [observed behavior or \`not required\`]
- Mismatch: [why prior/current behavior was wrong or \`none\`]
- Fix intent: [correction applied or \`none\`]
- Changed: [file paths]
- Verification: [checks run or skipped]
- Notes: [blockers or non-obvious decisions only]
EOF

printf '%s\n' "$OUTPUT_FILE"
