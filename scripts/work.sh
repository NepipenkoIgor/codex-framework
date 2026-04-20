#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

[ $# -ge 1 ] || fail "usage: work.sh <issue-number-or-url> [--refresh]"

issue_ref="$1"
mode="${2:-}"
ROOT="$(framework_root)"
PROJECT_ROOT="$(project_root)"

parse_issue_number() {
  local ref="$1"
  if printf '%s' "$ref" | grep -Eq '^[0-9]+$'; then
    printf '%s\n' "$ref"
    return 0
  fi
  if printf '%s' "$ref" | grep -Eq '/issues/[0-9]+'; then
    printf '%s\n' "$ref" | grep -oE '/issues/[0-9]+' | grep -oE '[0-9]+'
    return 0
  fi
  return 1
}

ensure_issue_worktree() {
  local repo_root="$1"
  local issue_number="$2"
  local project_name branch_name wt_dir
  project_name="$(basename "$repo_root")"
  branch_name="fix/$issue_number"
  wt_dir="${repo_root}/../${project_name}-${issue_number}"

  if [ -d "$wt_dir" ]; then
    printf '%s\n' "$wt_dir"
    return 0
  fi

  printf 'creating worktree: %s -> %s\n' "$branch_name" "$wt_dir" >&2
  git -C "$repo_root" worktree add "$wt_dir" -b "$branch_name" >/dev/null 2>&1 \
    || git -C "$repo_root" worktree add "$wt_dir" "$branch_name" >/dev/null 2>&1 \
    || fail "failed to create or open worktree for branch $branch_name"

  printf '%s\n' "$wt_dir"
}

if git rev-parse --show-toplevel >/dev/null 2>&1; then
  issue_number="$(parse_issue_number "$issue_ref" || true)"
  [ -n "$issue_number" ] || fail "could not parse issue number from: $issue_ref"
  PROJECT_ROOT="$(ensure_issue_worktree "$PROJECT_ROOT" "$issue_number")"
fi

ensure_project_bootstrap "$PROJECT_ROOT"
spec_file="$(cd "$PROJECT_ROOT" && bash "$ROOT/scripts/extract-spec.sh" "$issue_ref" "$mode")"

title="$(grep -m1 '^# ' "$spec_file" | sed 's/^# *//' || true)"
summary="$(sed -n '/^## Summary$/,/^## /p' "$spec_file" | sed '1d;$d' | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-500)"
decision="$(bash "$ROOT/scripts/codex-fw.sh" route "$title $summary")"
role="$(printf '%s\n' "$decision" | sed -n 's/.*role=\([^ ]*\).*/\1/p')"
skills="$(printf '%s\n' "$decision" | sed -n 's/.*skills=\([^ ]*\).*/\1/p')"
tier="$(printf '%s\n' "$decision" | sed -n 's/.*tier=\([^ ]*\).*/\1/p')"
model="$(printf '%s\n' "$decision" | sed -n 's/.*model=\([^ ]*\).*/\1/p')"
reasoning="$(printf '%s\n' "$decision" | sed -n 's/.*reasoning=\([^ ]*\).*/\1/p')"
log_file="$(
  cd "$PROJECT_ROOT"
  log_task_decision "issue=$issue_ref title=$title" "$role" "$skills" "$tier" "$model" "$reasoning"
)"
brief_file="$(cd "$PROJECT_ROOT" && bash "$ROOT/scripts/task-brief.sh" --task "$title $summary" --spec "$spec_file")"
plan_file="$(cd "$PROJECT_ROOT" && bash "$ROOT/scripts/plan.sh" --task "$title $summary" --spec "$spec_file")"

print_section "Issue"
info "root: $PROJECT_ROOT"
info "spec: $spec_file"
info "brief: $brief_file"
info "plan: $plan_file"
info "role: $role"
info "skills: $skills"
info "tier: $tier"
info "model: $model"
info "reasoning: $reasoning"
info "log: $log_file"

prompt="Work issue ${issue_ref}. Read ${plan_file} first and show that plan. Wait for explicit 'go'. Then read ${brief_file} and ${spec_file}. Follow CODEX.md and update the spec as work progresses."
cd "$PROJECT_ROOT"
exec codex -m "$model" "$prompt"
