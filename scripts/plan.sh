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
tester_model="$(tier_model medium)"
tester_reasoning="$(tier_reasoning medium)"
pm_model="$(tier_model low)"
pm_reasoning="$(tier_reasoning low)"
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
elif printf '%s' "$task_lc" | grep -Eq 'review github|review pr|pull request review|check ci|review comments'; then
  steps="$(make_step 1 reviewer "$step_model" "$step_reasoning" "$TASK" "$step_skills")"
  steps="$steps
$(make_step 2 tester "$tester_model" "$tester_reasoning" "check CI status and targeted verification signals" "ci-status, frontend-test, backend-test")"
  flow="⚡ Parallel"
  display_role="reviewer"
elif printf '%s' "$role" | grep -Eq '^builder|^fixer$|^refactorer$'; then
  steps="$(make_step 1 "$step_role" "$step_model" "$step_reasoning" "$TASK" "$step_skills")"
  steps="$steps
$(make_step 2 tester "$tester_model" "$tester_reasoning" "run targeted verification and regression checks" "frontend-test, backend-test")"
elif [ "$role" = "architect" ]; then
  steps="$(make_step 1 architect "$step_model" "$step_reasoning" "$TASK" "$step_skills")"
  steps="$steps
$(make_step 2 project-manager "$pm_model" "$pm_reasoning" "turn the design into an implementation-ready brief" "spec, process-hygiene")"
else
  steps="$(make_step 1 "$step_role" "$step_model" "$step_reasoning" "$TASK" "$step_skills")"
fi

status_block=$(cat <<EOF
## Update Style

Use these short status blocks during work:

\`\`\`text
⏺ $(role_emoji "$display_role") $(role_alias "$display_role")~$(model_tag "$display_reasoning") In Progress
🤖 $display_model | Tier: $display_reasoning
📚 $(decorate_skill_list "$display_skills")
\`\`\`

\`\`\`text
✅ $(role_emoji "$display_role") $(role_alias "$display_role")~$(model_tag "$display_reasoning") Done
🤖 $display_model | Tier: $display_reasoning
📚 $(decorate_skill_list "$display_skills")
\`\`\`
EOF
)

if [ -z "$OUTPUT_FILE" ]; then
  OUTPUT_FILE="$(run_root)/$(date -u +"%Y%m%dT%H%M%SZ")-plan.md"
fi

cat > "$OUTPUT_FILE" <<EOF
⏺ 📐 Plan: $plan_title

$steps

$flow

Ready — type \`go\` to start.

$status_block
EOF

printf '%s\n' "$OUTPUT_FILE"
