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
if [ "${CODEX_SKIP_BOOTSTRAP:-0}" != "1" ]; then
  ensure_project_bootstrap "$ROOT"
fi
load_project_commands
if [ "${CODEX_SKIP_REPO_REFRESH:-0}" = "1" ]; then
  load_repo_intelligence
else
  refresh_repo_intelligence >/dev/null
  load_repo_intelligence
fi
ensure_run_root
ensure_cache_dir

if [ -z "$SPEC_FILE" ]; then
  SPEC_FILE="$(active_spec_file || true)"
fi

decision="$(bash "$FRAMEWORK_ROOT/scripts/codex-fw.sh" route "$TASK")"
role="$(printf '%s\n' "$decision" | sed -n 's/.*role=\([^ ]*\).*/\1/p')"
model="$(printf '%s\n' "$decision" | sed -n 's/.*model=\([^ ]*\).*/\1/p')"
reasoning="$(printf '%s\n' "$decision" | sed -n 's/.*reasoning=\([^ ]*\).*/\1/p')"
route="$(route_badge "$role" "$model" "$reasoning")"
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
memory_status="$(bash "$FRAMEWORK_ROOT/scripts/memory-state.sh" status 2>/dev/null || true)"
memory_context="$(bash "$FRAMEWORK_ROOT/scripts/memory-state.sh" context "$TASK" 2>/dev/null || echo "none")"
memory_source="$(printf '%s\n' "$memory_status" | sed -n 's/^source=//p')"
memory_dir="$(printf '%s\n' "$memory_status" | sed -n 's/^memory_dir=//p')"

package_manager_from_package_json() {
  [ -f "$ROOT/package.json" ] || return 1
  python3 - <<PY 2>/dev/null
import json
from pathlib import Path

package_json = Path("$ROOT/package.json")
try:
    data = json.loads(package_json.read_text(encoding="utf-8"))
except Exception:
    raise SystemExit(1)

value = str(data.get("packageManager", "")).strip()
if not value:
    raise SystemExit(1)
print(value.split("@", 1)[0].strip())
PY
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
elif [ "$package_runner" = "none" ]; then
  case "$(package_manager_from_package_json || true)" in
    bun)
      package_runner="bun run"
      package_exec="bunx"
      ;;
    pnpm)
      package_runner="pnpm"
      package_exec="pnpm exec"
      ;;
    yarn)
      package_runner="yarn"
      package_exec="yarn"
      ;;
  esac
fi

if [ "$package_runner" = "none" ] && { [ -f "$ROOT/package-lock.json" ] || [ -f "$ROOT/package.json" ]; }; then
  package_runner="npm run"
  package_exec="npx"
fi

baseline_skills="$(resolve_domain_baseline_skills "$role" "$domains")"
stack_skills="$(resolve_stack_skills "$role" "$stack")"
map_skills="$(resolve_skills_for_domains "$domains" "$task_lc")"
feature_skills="$(resolve_feature_skills "$features")"
task_extra_skills="none"
tailwind_first_repo="no"
if csv_contains "$policy" "tailwind-first" || csv_contains "$policy" "avoid-inline-styles"; then
  tailwind_first_repo="yes"
elif stack_has "$stack" "tailwind"; then
  tailwind_first_repo="yes"
elif printf '%s' "$features" | grep -Eq '(^|,)(tailwind|utility-classes|ui-primitives|design-system)(,|$)'; then
  tailwind_first_repo="yes"
fi

task_is_ui_like="no"
if task_contains "$task_lc" 'ui|frontend|component|page|style|css|layout|accessibility|responsive|visual|avatar|image|hero|section|copy|text|landing|menu|modal|drawer|sidebar|navbar|header|footer|card|button|input|form|sheet|popover|dropdown|tabs|toast|dialog|overlay|panel'; then
  task_is_ui_like="yes"
fi

if [ "$tailwind_first_repo" = "yes" ] && [ "$task_is_ui_like" = "yes" ]; then
  task_extra_skills="$(merge_skill_csvs "$task_extra_skills" "design-system-implement,ui-consistency-audit,responsive-design")"
fi

task_contains "$task_lc" 'new api|endpoint|request boundary|schema change' && task_extra_skills="$(merge_skill_csvs "$task_extra_skills" "api-design,data-validation-design,audit-logging")"
task_contains "$task_lc" 'migration|migrations|schema change|db change|database change|seed data|reference data|миграц|схем' && task_extra_skills="$(merge_skill_csvs "$task_extra_skills" "database-migration")"
task_contains "$task_lc" 'review|audit|аудит|ревью|провер|проанализ|анализ' && task_extra_skills="$(merge_skill_csvs "$task_extra_skills" "security-audit")"
task_contains "$task_lc" 'review|ревью|аудит|провер|проанализ|анализ' && csv_contains "$domains" "frontend" && task_extra_skills="$(merge_skill_csvs "$task_extra_skills" "ui-consistency-audit,accessibility-audit")"
task_contains "$task_lc" 'review|ревью|аудит|провер|проанализ|анализ' && csv_contains "$domains" "backend" && task_extra_skills="$(merge_skill_csvs "$task_extra_skills" "backend-review,performance")"
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
  scope_summary="$(git diff --name-only HEAD 2>/dev/null | sed 's#^\./##' | head -n 8)"
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
elif [ "$task_shape" = "review" ] || [ "$task_shape" = "strategic" ]; then
  execution_pattern="review-first"
elif [ "$task_shape" = "mechanical" ]; then
  execution_pattern="fast-path"
fi

handoff_id="none"
if [ "$contract_required" = "yes" ] || task_contains "$task_lc" 'parallel|handoff|sub-agent|subagent'; then
  handoff_id="$(date -u +"handoff-%Y%m%dT%H%M%SZ")"
  bash "$FRAMEWORK_ROOT/scripts/handoff-state.sh" init "$handoff_id" >/dev/null 2>&1 || true
fi

agent_runtime_type="$(bash "$FRAMEWORK_ROOT/scripts/agent-registry.sh" get "$role" runtime_type 2>/dev/null || printf 'default\n')"
agent_work_mode="$(bash "$FRAMEWORK_ROOT/scripts/agent-registry.sh" get "$role" work_mode 2>/dev/null || printf 'unknown\n')"
agent_parallel_safe="$(bash "$FRAMEWORK_ROOT/scripts/agent-registry.sh" get "$role" parallel_safe 2>/dev/null || printf 'unknown\n')"
agent_ownership_required="$(bash "$FRAMEWORK_ROOT/scripts/agent-registry.sh" get "$role" ownership_required 2>/dev/null || printf 'unknown\n')"
agent_summary="$(bash "$FRAMEWORK_ROOT/scripts/agent-registry.sh" get "$role" summary 2>/dev/null || printf 'No named agent registry entry found.\n')"
delegation_recommended="no"
[ "$handoff_id" != "none" ] && delegation_recommended="yes"
supporting_named_agents="none"
if task_contains "$task_lc" 'frontend|ui|form|component|page|style|css|layout' \
  && task_contains "$task_lc" 'backend|api|endpoint|service|database|db|auth|webhook'; then
  supporting_named_agents="architect,builder-backend,builder-frontend,tester"
elif [ "$contract_required" = "yes" ]; then
  supporting_named_agents="architect,$role,tester"
elif printf '%s' "$role" | grep -Eq '^builder|^fixer$|^refactorer$'; then
  supporting_named_agents="$role,tester"
fi

retry_chain="$(model_retry_chain "$model")"

verification=()
[ -n "${TEST_CMD:-}" ] && verification+=("test: $TEST_CMD")
[ -n "${LINT_CMD:-}" ] && verification+=("lint: $LINT_CMD")
[ -n "${BUILD_CMD:-}" ] && verification+=("build: $BUILD_CMD")
task_contains "$task_lc" 'review|audit|аудит|ревью|провер|проанализ|анализ' && verification+=("findings-first review output")
[ "$requirement_check" = "yes" ] && verification+=("requirement check completed before edits")
if printf '%s' "$stack" | grep -Eq '(react|nextjs|vue|angular|playwright|blazor)'; then
  verification+=("browser/spec verification when UI-visible behavior changes")
fi
[ "${#verification[@]}" -gt 0 ] || verification+=("manual targeted verification")

github_preferred="not relevant"
github_secondary="not relevant"
github_local="not relevant"
if task_contains "$task_lc" 'github|pull request|pr|issue|review|comment'; then
  if printf '%s\n' "$capabilities_report" | grep -q 'github_structured=yes'; then
    github_preferred="structured GitHub tools"
    github_secondary="gh CLI"
    github_local="local git only"
  elif printf '%s\n' "$capabilities_report" | grep -q 'github_cli=yes' && printf '%s\n' "$capabilities_report" | grep -q 'github_auth_ready=yes'; then
    github_preferred="gh CLI"
    github_secondary="local git only"
    github_local="local git only"
  elif git rev-parse --show-toplevel >/dev/null 2>&1; then
    github_preferred="local git only"
    github_secondary="none"
    github_local="local git only"
  else
    github_preferred="none"
    github_secondary="none"
    github_local="none"
  fi
fi

if [ -z "$OUTPUT_FILE" ]; then
  OUTPUT_FILE="$(run_root)/$(date -u +"%Y%m%dT%H%M%SZ")-brief.md"
fi

human_capabilities_summary() {
  local lines=""
  if printf '%s\n' "$capabilities_report" | grep -q 'git=yes'; then
    lines="$lines- Git access is available.\n"
  fi
  if printf '%s\n' "$capabilities_report" | grep -q 'github_cli=yes'; then
    lines="$lines- GitHub CLI is available.\n"
  fi
  if printf '%s\n' "$capabilities_report" | grep -q 'github_auth_ready=yes'; then
    lines="$lines- GitHub auth is ready.\n"
  fi
  if printf '%s\n' "$capabilities_report" | grep -q 'browser_checks_local=yes'; then
    lines="$lines- Browser checks can run locally.\n"
  fi
  if printf '%s\n' "$capabilities_report" | grep -q 'browser_checks_local=no'; then
    lines="$lines- Browser checks are not available here.\n"
  fi
  if printf '%s\n' "$capabilities_report" | grep -q 'codex_hooks_configured=yes'; then
    lines="$lines- Codex runtime hooks are configured.\n"
  elif printf '%s\n' "$capabilities_report" | grep -q 'codex_hooks_path=missing required hook config'; then
    lines="$lines- Codex runtime hooks are missing required config; run hook installation/doctor before Desktop lifecycle work.\n"
  fi
  if [ -z "$lines" ]; then
    printf -- '- Capabilities could not be summarized.\n'
    return 0
  fi
  printf '%b' "$lines"
}

human_repo_habits_summary() {
  local lines=""
  if printf '%s' "$policy" | grep -Eq '(^|,)(tailwind-first|utility-classes)(,|$)'; then
    lines="$lines- This repo prefers utility classes and shared UI tokens.\n"
  fi
  if printf '%s' "$policy" | grep -Eq '(^|,)prefer-cva-variants(,|$)'; then
    lines="$lines- Variant helpers are preferred for component styling.\n"
  fi
  if [ -z "$lines" ]; then
    printf -- '- No special repo habits were detected.\n'
    return 0
  fi
  printf '%b' "$lines"
}

cat > "$OUTPUT_FILE" <<EOF
## Goal
$TASK

## Routing
- Route badge: $route
- Chosen owner: $role
- Model: $model
- Reasoning depth: $reasoning
- Retry path: $retry_chain

## What We Found
- Stack: $stack
- Features: $features
- Repo policy: $policy
- Relevant areas: $domains
- Task flags: $task_flags
- Task shape: $task_shape
- Framework notes: read CODEX.md, CODEX.concepts.md, ORCHESTRATOR_REFERENCE.md, and CODEX.skills.md first

## Nearby Changes
$(if [ -n "$scope_summary" ]; then printf -- '- %s\n' "$scope_summary"; else echo "- No current diff to review."; fi)

## Checks We Have
- Package runner: $package_runner
- Direct local binaries: $package_exec
- Test command: ${TEST_CMD:-}
- Lint command: ${LINT_CMD:-}
- Build command: ${BUILD_CMD:-}
- Dev command: ${DEV_CMD:-}

## Existing Capabilities
$(human_capabilities_summary)

## Repo Habits
$(human_repo_habits_summary)

## Memory Context
- Loaded: yes
- Source: ${memory_source:-unknown}
- Directory: ${memory_dir:-unknown}

\`\`\`text
$memory_context
\`\`\`

## GitHub
- Preferred path: $github_preferred
- Secondary path: $github_secondary
- Local path: $github_local

## Working Rules
- Respect the repo's existing patterns.
- Leave unrelated changes alone.
- Keep the change narrow.
- Treat skills as lazy context: identify names first, load bodies only when they are needed.
- Use precise orchestration language: skills are loaded, the current named agent works, and sub-agents are only spawned by explicit delegation.
- If a skill name could be mistaken for an agent, say "skill \`<name>\`" and note that no sub-agent was spawned.
- Prefer the repo's own maps and helpers over ad hoc guesses.
- For JS/TS repos, use the detected package runner and local binary executor for direct commands.
- Update specs when the task is spec-driven.
- Run guard scans before close-out for code or config changes.
- Use a contract-first approach when the task crosses API, schema, or parallel ownership boundaries.
- For requirement-sensitive tasks, restate the requirement, compare it to current behavior, identify the mismatch, and only then change code.
- For issue/spec work, treat the implementation as delta-first: map each active requirement and comment clarification to current project behavior, mark already-satisfied items, and change only what is missing or incorrect.
- If the repo is Tailwind-first or asks to avoid inline styles, prefer utility classes and shared tokens/components over inline style objects.
- Read nearby files and shared UI primitives before introducing a new styling pattern.
- Prefer existing helpers, shared components, and file-layer boundaries over one-off abstractions.
- If the repo conventions mention use-zod-validation, use-cn-helper, use-cva-variants, or shared test helpers, follow them instead of inventing a parallel pattern.

## Best-Fit Skills
- Primary skill: $primary_skill
- Supporting skills: $supporting_skills
- Resolution path: domain baseline -> stack -> features -> maps -> task extras
- Skills are lazy context for the named agent; load bodies only when needed.

## Named Agent
- Primary named agent: $role
- Current-session language: working as named agent \`$role\`
- Runtime spawn type: $agent_runtime_type
- Work mode: $agent_work_mode
- Parallel safe: $agent_parallel_safe
- Ownership required: $agent_ownership_required
- Summary: $agent_summary
- Candidate named agents for this task: $supporting_named_agents

## Spec
- Path: ${SPEC_FILE:-none}
- Status: $spec_status

## Requirement Check
- Needed: $requirement_check
- Before edits, spell out:
  - Requirement: the intended behavior from the user, spec, or comment
  - Current behavior: what the code or current change actually does
  - Mismatch: why that behavior does not satisfy the requirement
  - Coverage: which parts are already satisfied and should be left alone
  - Fix intent: the smallest correction that closes only the missing or incorrect gap
- If the requirement evidence is ambiguous, stop and resolve that ambiguity before editing.

## Coordination
- Execution pattern: $execution_pattern
- Contract required: $contract_required
- Handoff state: $handoff_id
- Delegation recommended: $delegation_recommended
- Sub-agent language: say "spawn sub-agent" only after explicit delegation; otherwise say "no sub-agent spawned"
- Spawn prompt builder: codex-fw agent prompt $role --task "<task>" --skills "$resolved_skills" --ownership "<files or responsibility>" --handoff "$handoff_id"
- The main session keeps the critical path. Spawn this named agent only for bounded work with clear ownership.

## How We'll Verify
$(printf -- '- %s\n' "${verification[@]}")
- guard: bash $FRAMEWORK_ROOT/scripts/guard-scan.sh --changed
- quality: bash $FRAMEWORK_ROOT/scripts/quality-check.sh --changed

## Output Contract
Use this exact final response shape. Keep section names and ordering. Use \`not required\`, \`none\`, or \`not run\` instead of omitting sections.
Do not use the old label format \`Status: ...\`, \`Requirement: ...\`, or \`Fix intent applied: ...\`.

✅ $route — done | partial | blocked

**Requirement**
[restated requirement or \`not required\`]

**Current Behavior**
[observed behavior or \`not required\`]

**Mismatch**
[why the previous/current behavior was wrong or \`none\`]

**Fix Intent**
[short statement of the correction]

**Changed**
- [file or behavior changed]

**Verification**
- [command/check run, or \`not run\` with reason]

**Memory**
- loaded from ${memory_source:-unknown}; recorded | skipped with reason

**Notes**
- [blockers, residual risk, pre-existing unrelated changes, or \`none\`]
EOF

printf '%s\n' "$OUTPUT_FILE"
