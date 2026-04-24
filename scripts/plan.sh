#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

usage() {
  cat <<EOF
usage: plan.sh --task "<task text>" [--spec <spec-file>] [--output <file>]
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

FRAMEWORK_ROOT="$(framework_root)"
ensure_run_root

if [ -n "$SPEC_FILE" ]; then
  brief_file="$(bash "$FRAMEWORK_ROOT/scripts/task-brief.sh" --task "$TASK" --spec "$SPEC_FILE")"
else
  brief_file="$(bash "$FRAMEWORK_ROOT/scripts/task-brief.sh" --task "$TASK")"
fi

role="$(sed -n 's/^- Role: //p' "$brief_file")"
model="$(sed -n 's/^- Model: //p' "$brief_file")"
reasoning="$(sed -n 's/^- Reasoning: //p' "$brief_file")"
primary_skill="$(sed -n 's/^- Primary: //p' "$brief_file")"
supporting_skills="$(sed -n 's/^- Supporting: //p' "$brief_file")"

step_role="$role"
step_model="$model"
step_reasoning="$reasoning"
step_skills="$primary_skill"
if [ -n "$supporting_skills" ] && [ "$supporting_skills" != "none" ]; then
  step_skills="$step_skills, $supporting_skills"
fi

make_step() {
  local number="$1"
  local role_name="$2"
  local role_model="$3"
  local role_reasoning="$4"
  local description="$5"
  local skills="$6"
  {
    printf '%s. %s %s~%s — %s\n' \
      "$number" \
      "$(role_emoji "$role_name")" \
      "$(role_alias "$role_name")" \
      "$(model_tag "$role_reasoning")" \
      "$description"
    printf '   🤖 Model: %s | Tier: %s\n' "$role_model" "$role_reasoning"
    if [ -n "$skills" ] && [ "$skills" != "none" ]; then
      printf '   📚 Skills: %s\n' "$(decorate_skill_list "$skills")"
    fi
  }
}

parallel_steps() {
  local step_lines="$1"
  printf '%s\n\n⚡ Parallel\n' "$step_lines"
}

plan_title="$TASK"
steps=""
flow="⛓️  Sequential"
task_lc="$(printf '%s' "$TASK" | tr '[:upper:]' '[:lower:]')"
task_flags="$(detect_task_flags "$task_lc" "$(bash "$FRAMEWORK_ROOT/scripts/detect-project-stack.sh" "$(project_root)")")"
task_shape="$(classify_task_shape "$task_lc")"
requirement_check="no"
requires_requirement_check "$task_lc" && requirement_check="yes"
tester_model="$(tier_model medium)"
tester_reasoning="$(tier_reasoning medium)"
pm_model="$(tier_model low)"
pm_reasoning="$(tier_reasoning low)"
arch_model="$(tier_model high)"
arch_reasoning="$(tier_reasoning high)"
display_role="$step_role"
display_model="$step_model"
display_reasoning="$step_reasoning"
display_skills="$step_skills"

if printf '%s' "$task_lc" | grep -Eq 'create pr|pull request|open pr'; then
  steps="$(make_step 1 tester "$tester_model" "$tester_reasoning" "run test suite and readiness checks" "frontend-test, backend-test, ci-status")"
  steps="$steps
$(make_step 2 project-manager "$pm_model" "$pm_reasoning" "create PR with full change summary" "project-setup, process-hygiene")"
  display_role="tester"
  display_model="$tester_model"
  display_reasoning="$tester_reasoning"
  display_skills="frontend-test, backend-test, ci-status"
elif printf '%s' "$task_lc" | grep -Eq 'framework gap|production readiness|operating model|roadmap'; then
  steps="$(make_step 1 framework-manager "$step_model" "$step_reasoning" "analyze the framework slice and define the implementation contract" "$step_skills")"
  steps="$steps
$(make_step 2 framework-manager "$step_model" "$step_reasoning" "implement the framework changes and wire validation" "$step_skills")
$(make_step 3 tester "$tester_model" "$tester_reasoning" "run framework health, doctor, and post-change verification" "frontend-test, backend-test, ci-status")"
elif printf '%s' "$task_lc" | grep -Eq 'review github|review pr|pull request review|check ci|review comments'; then
  steps="$(make_step 1 reviewer "$step_model" "$step_reasoning" "$TASK" "$step_skills")"
  steps="$steps
$(make_step 2 tester "$tester_model" "$tester_reasoning" "check CI status and targeted verification signals" "ci-status, frontend-test, backend-test")"
  flow="⚡ Parallel"
  display_role="reviewer"
elif printf '%s' "$task_lc" | grep -Eq 'visual|layout|spacing|color|typography|hover|animation|responsive|ui polish|css'; then
  steps="$(make_step 1 reviewer "$step_model" "$step_reasoning" "review visual rows and pinpoint affected files" "frontend-review, ui-consistency-audit")
$(make_step 2 fixer "$(tier_model low)" "$(tier_reasoning low)" "apply the mechanical visual fixes in small batches" "frontend-debug, responsive-design")
$(make_step 3 reviewer "$step_model" "$step_reasoning" "re-check the visual result and residual gaps" "frontend-review, ui-consistency-audit")"
elif [ "$requirement_check" = "yes" ]; then
  steps="$(make_step 1 reviewer "$step_model" "$step_reasoning" "restate the requirement, compare current behavior, and report the mismatch before edits" "frontend-review,backend-review,process-hygiene")
$(make_step 2 "$step_role" "$step_model" "$step_reasoning" "apply only the smallest correction that satisfies the requirement exactly" "$step_skills")
$(make_step 3 tester "$tester_model" "$tester_reasoning" "run targeted verification and repo-quality checks, then confirm the requirement is now met" "frontend-test, backend-test")"
  flow="⛓️  Requirement Gate"
elif printf '%s' "$role" | grep -Eq '^builder|^fixer$|^refactorer$'; then
  if printf '%s' "$task_flags" | grep -Eq 'contract'; then
    steps="$(make_step 1 architect "$arch_model" "$arch_reasoning" "define the contract and ownership boundaries before implementation" "api-design, backend-architecture, frontend-architecture")
$(make_step 2 "$step_role" "$step_model" "$step_reasoning" "$TASK" "$step_skills")
$(make_step 3 tester "$tester_model" "$tester_reasoning" "run targeted verification, regression checks, and repo-quality checks" "frontend-test, backend-test")"
  else
    steps="$(make_step 1 "$step_role" "$step_model" "$step_reasoning" "$TASK" "$step_skills")
$(make_step 2 tester "$tester_model" "$tester_reasoning" "run targeted verification, regression checks, and repo-quality checks" "frontend-test, backend-test")"
  fi
elif [ "$role" = "architect" ]; then
  steps="$(make_step 1 architect "$step_model" "$step_reasoning" "$TASK" "$step_skills")"
  steps="$steps
$(make_step 2 project-manager "$pm_model" "$pm_reasoning" "turn the design into an implementation-ready brief" "spec, process-hygiene")"
else
  steps="$(make_step 1 "$step_role" "$step_model" "$step_reasoning" "$TASK" "$step_skills")"
fi

if [ "$task_shape" = "mechanical" ] && [ "$role" != "architect" ] && [ "$role" != "reviewer" ]; then
  flow="⚡ Fast Path"
fi

progress_note="Progress updates during execution will show the active role, model, tier, and the most relevant active skills."

if [ -z "$OUTPUT_FILE" ]; then
  OUTPUT_FILE="$(run_root)/$(date -u +"%Y%m%dT%H%M%SZ")-plan.md"
fi

cat > "$OUTPUT_FILE" <<EOF
⏺ 📐 Plan: $plan_title

$steps

$flow

Ready — type \`go\` to start.

Requirement-sensitive task: $requirement_check
If yes, step 1 is mandatory and edits must not start before the mismatch is stated.

$progress_note
EOF

printf '%s\n' "$OUTPUT_FILE"
