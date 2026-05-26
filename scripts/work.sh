#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

[ $# -ge 1 ] || fail "usage: work.sh <issue-number-or-url> [--refresh] [--resume] [--cleanup|--cleanup-all]"

issue_ref="$1"
shift || true
mode=""
worktree_mode="fresh"
while [ $# -gt 0 ]; do
  case "$1" in
    --refresh) mode="--refresh" ;;
    --resume) worktree_mode="resume" ;;
    --cleanup|--cleanup-all) worktree_mode="cleanup" ;;
    *) fail "unknown work option: $1" ;;
  esac
  shift
done
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
  local mode="${3:-fresh}"
  local project_name branch_name wt_dir current_branch unmerged_files base_branch base_ref base_sha base_short suffix attempt branch_candidate wt_candidate remote_url metadata_file
  project_name="$(basename "$repo_root")"
  if [ "$mode" = "resume" ]; then
    wt_dir="$(bash "$ROOT/scripts/issue-worktrees.sh" resume "$issue_number" "$repo_root")"
    [ -n "$wt_dir" ] || fail "no existing issue worktree found for $issue_number"

    git -C "$wt_dir" rev-parse --show-toplevel >/dev/null 2>&1 \
      || fail "existing issue worktree is not a git repository: $wt_dir"
    unmerged_files="$(git -C "$wt_dir" diff --name-only --diff-filter=U 2>/dev/null || true)"
    if [ -n "$unmerged_files" ]; then
      fail "existing issue worktree has unresolved conflicts: $wt_dir
Resolve or remove it before rerunning.
First conflicted files:
$(printf '%s\n' "$unmerged_files" | sed -n '1,10p')"
    fi
    current_branch="$(git -C "$wt_dir" symbolic-ref --short HEAD 2>/dev/null || true)"
    if [ -z "$current_branch" ]; then
      fail "existing issue worktree is on detached HEAD: $wt_dir
Create/check out a branch there, or remove the worktree and rerun."
    fi
    printf 'resuming worktree\n' >&2
    printf 'worktree branch: %s\n' "$current_branch" >&2
    printf 'worktree path: %s\n' "$wt_dir" >&2
    printf '%s\n' "$wt_dir"
    return 0
  fi

  base_branch="$(resolve_base_branch "$repo_root")" \
    || fail "could not resolve default branch for issue worktree"
  remote_url="$(git -C "$repo_root" config --get remote.origin.url 2>/dev/null || true)"
  if [ -n "$remote_url" ]; then
    printf 'fetching default branch: origin/%s\n' "$base_branch" >&2
    git -C "$repo_root" fetch origin "$base_branch" --prune >/dev/null 2>&1 \
      || fail "failed to fetch origin/$base_branch for fresh issue worktree"
  fi
  base_ref="$base_branch"
  if git -C "$repo_root" rev-parse --verify "origin/$base_branch" >/dev/null 2>&1; then
    base_ref="origin/$base_branch"
  fi
  base_sha="$(git -C "$repo_root" rev-parse "$base_ref^{commit}")" \
    || fail "could not resolve base SHA for $base_ref"
  base_short="$(git -C "$repo_root" rev-parse --short=12 "$base_sha")"

  suffix="$base_short"
  attempt=1
  while :; do
    if [ "$attempt" -eq 1 ]; then
      branch_candidate="fix/${issue_number}-${suffix}"
      wt_candidate="${repo_root}/../${project_name}-${issue_number}-${suffix}"
    else
      branch_candidate="fix/${issue_number}-${suffix}-${attempt}"
      wt_candidate="${repo_root}/../${project_name}-${issue_number}-${suffix}-${attempt}"
    fi
    if [ ! -e "$wt_candidate" ] && ! git -C "$repo_root" show-ref --verify --quiet "refs/heads/$branch_candidate"; then
      branch_name="$branch_candidate"
      wt_dir="$wt_candidate"
      break
    fi
    attempt=$((attempt + 1))
  done

  printf 'creating worktree\n' >&2
  printf 'worktree branch: %s\n' "$branch_name" >&2
  printf 'worktree base: %s\n' "$base_ref" >&2
  printf 'worktree base sha: %s\n' "$base_short" >&2
  printf 'worktree path: %s\n' "$wt_dir" >&2
  git -C "$repo_root" worktree add "$wt_dir" -b "$branch_name" "$base_ref" >/dev/null 2>&1 \
    || fail "failed to create or open worktree for branch $branch_name"

  sync_worktree_env_files "$repo_root" "$wt_dir"

  mkdir -p "$wt_dir/.codex"
  metadata_file="$wt_dir/.codex/worktree.env"
  cat > "$metadata_file" <<EOF
ISSUE_NUMBER=$issue_number
ISSUE_REF=$issue_ref
BASE_BRANCH=$base_branch
BASE_REF=$base_ref
BASE_SHA=$base_sha
CREATED_AT=$(timestamp_utc)
MODE=fresh
EOF
  printf '%s\n' "$wt_dir"
}

if git rev-parse --show-toplevel >/dev/null 2>&1; then
  issue_number="$(parse_issue_number "$issue_ref" || true)"
  [ -n "$issue_number" ] || fail "could not parse issue number from: $issue_ref"
  if [ "$worktree_mode" = "cleanup" ]; then
    bash "$ROOT/scripts/issue-worktrees.sh" cleanup "$issue_number" "$PROJECT_ROOT"
    exit 0
  fi
  SOURCE_PROJECT_ROOT="$PROJECT_ROOT"
  PROJECT_ROOT="$(ensure_issue_worktree "$PROJECT_ROOT" "$issue_number" "$worktree_mode")"
  sync_worktree_memory "$SOURCE_PROJECT_ROOT" "$PROJECT_ROOT"
fi

print_section "Work Progress"
info "stage: initialize issue workflow"
info "issue: $issue_ref"

run_with_spinner "bootstrap project state" ensure_project_bootstrap "$PROJECT_ROOT" >/dev/null
info "stage: bootstrap project state"
spec_file="$(cd "$PROJECT_ROOT" && run_with_spinner "extract spec" bash "$ROOT/scripts/extract-spec.sh" "$issue_ref" "$mode")"
info "stage: extract spec"

title="$(grep -m1 '^# ' "$spec_file" | sed 's/^# *//' || true)"
summary="$(sed -n '/^## Summary$/,/^## /p' "$spec_file" | sed '1d;$d' | tr '\n' ' ' | sed 's/  */ /g' | cut -c1-500)"
info "stage: route task"
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
brief_file="$(
  cd "$PROJECT_ROOT"
  CODEX_SKIP_BOOTSTRAP=1 CODEX_SKIP_REPO_REFRESH=1 run_with_spinner "generate task brief" \
    bash "$ROOT/scripts/task-brief.sh" --task "$title $summary" --spec "$spec_file"
)"
plan_file="$(
  cd "$PROJECT_ROOT"
  CODEX_SKIP_BOOTSTRAP=1 CODEX_SKIP_REPO_REFRESH=1 run_with_spinner "generate session plan" \
    bash "$ROOT/scripts/plan.sh" --task "$title $summary" --spec "$spec_file" --brief "$brief_file"
)"

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
info "stage: launch Codex session"

delta_instruction="Treat this as delta-first issue work: use the issue body plus discussion comments as the active requirement source, compare them against the current project before editing, mark already-satisfied requirements as covered, and implement only missing or incorrect behavior."
task_flags="$(sed -n 's/^- Task flags: //p' "$brief_file")"
task_shape="$(sed -n 's/^- Task shape: //p' "$brief_file")"
if codex_should_wait_for_go "$role" "$reasoning" "$task_shape" "$task_flags" "$title $summary"; then
  prompt="Work issue ${issue_ref}. Print ${plan_file} verbatim first, preserving emoji, bullets, spacing, and wording. Wait for explicit 'go'. Then read ${brief_file} and ${spec_file}. ${delta_instruction} Follow CODEX.md and update the spec as work progresses. End with the task brief Output Contract exactly. Do not use old Status:/Requirement: closeout labels."
else
  prompt="Work issue ${issue_ref}. Print ${plan_file} verbatim first, preserving emoji, bullets, spacing, and wording. Then read ${brief_file} and ${spec_file}. ${delta_instruction} Follow CODEX.md and update the spec as work progresses. End with the task brief Output Contract exactly. Do not use old Status:/Requirement: closeout labels."
fi

commit_type_from_title() {
  local text="$1"
  if printf '%s' "$text" | grep -Eqi 'fix|bug|crash|broken|wrong behavior|regression'; then
    printf 'fix\n'
  elif printf '%s' "$text" | grep -Eqi 'refactor|simplify|cleanup|clean up|migrate|modernize'; then
    printf 'refactor\n'
  elif printf '%s' "$text" | grep -Eqi 'docs|readme|spec|copy'; then
    printf 'docs\n'
  elif printf '%s' "$text" | grep -Eqi 'test|coverage|qa|regression'; then
    printf 'test\n'
  else
    printf 'feat\n'
  fi
}

start_head="$(git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null || true)"
cd "$PROJECT_ROOT"
if ! codex_run -m "$model" "$prompt"; then
  fail "Codex session failed"
fi

record_memory_episode "$title $summary" "Issue session completed for $issue_ref." "issue,$role,$tier"

if codex_auto_submit; then
  if git -C "$PROJECT_ROOT" diff --quiet HEAD -- && [ -z "$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null || true)" ] && [ "$(git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null || true)" = "$start_head" ]; then
    info "stage: auto submit skipped (no changes to publish)"
  else
    if [ -n "$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null || true)" ]; then
      commit_type="$(commit_type_from_title "$title")"
      commit_message="${commit_type}(issue-${issue_number}): ${title}"
      info "stage: auto commit"
      bash "$ROOT/scripts/safe-commit.sh" "$commit_message" --all
    fi
    info "stage: create PR"
    bash "$ROOT/scripts/pr-create.sh" --title "$title"
  fi
fi
