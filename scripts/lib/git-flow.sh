slugify_worktree_label() {
  local label="$1"
  printf '%s' "$label" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g' | cut -c1-48
}

branch_prefix_for_task() {
  local task_lc
  task_lc="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"

  if printf '%s' "$task_lc" | grep -Eq '(^|[^a-z])(docs?|documentation|readme)([^a-z]|$)|док|ридми'; then
    printf 'docs\n'
  elif printf '%s' "$task_lc" | grep -Eq '(^|[^a-z])(test|tests|spec|e2e|playwright|vitest)([^a-z]|$)|тест'; then
    printf 'test\n'
  elif printf '%s' "$task_lc" | grep -Eq '(^|[^a-z])(refactor|cleanup|clean up|polish)([^a-z]|$)|рефактор|полиш|почист'; then
    printf 'chore\n'
  elif printf '%s' "$task_lc" | grep -Eq '(^|[^a-z])(fix|bug|bugfix|hotfix|repair)([^a-z]|$)|исправ|почин|баг|ошиб'; then
    printf 'fix\n'
  elif printf '%s' "$task_lc" | grep -Eq '(^|[^a-z])(chore|ci|build|deps?|dependency|maintenance)([^a-z]|$)|обслуж|зависим'; then
    printf 'chore\n'
  else
    printf 'feature\n'
  fi
}

sync_worktree_env_files() {
  local source_root="$1"
  local wt_dir="$2"
  local mode="${CODEX_WORKTREE_ENV_SYNC:-copy}"
  local source name target

  case "$mode" in
    0|false|FALSE|no|NO|off|OFF|none)
      return 0
      ;;
    copy|symlink)
      ;;
    *)
      printf 'warning: unknown CODEX_WORKTREE_ENV_SYNC=%s; expected copy, symlink, or 0\n' "$mode" >&2
      mode="copy"
      ;;
  esac

  find "$source_root" -maxdepth 1 \( -type f -o -type l \) \( -name '.env' -o -name '.env.*' \) | sort | while IFS= read -r source; do
    [ -n "$source" ] || continue
    name="$(basename "$source")"
    case "$name" in
      .env.example|.env.sample|.env.template|.env.*.example|.env.*.sample|.env.*.template)
        continue
        ;;
    esac

    target="$wt_dir/$name"
    [ -e "$target" ] && continue

    if [ "$mode" = "symlink" ]; then
      ln -s "$source" "$target" || continue
      printf 'linked env file: %s\n' "$name" >&2
    else
      cp -p "$source" "$target" || continue
      printf 'copied env file: %s\n' "$name" >&2
    fi
  done

  return 0
}

sync_worktree_memory() {
  local source_root="$1"
  local wt_dir="$2"
  local source_memory target_memory

  source_memory="$(cd "$source_root" && memory_root)"
  target_memory="$(cd "$wt_dir" && memory_root)"

  [ -d "$source_memory" ] || return 0
  mkdir -p "$target_memory"

  for name in project.md preferences.md decisions.local.md episodes.jsonl; do
    if [ -f "$source_memory/$name" ] && [ ! -f "$target_memory/$name" ]; then
      cp "$source_memory/$name" "$target_memory/$name" 2>/dev/null || true
    fi
  done
}

ensure_task_worktree() {
  local repo_root="$1"
  local task_text="$2"
  local project_name task_slug branch_prefix branch_name wt_dir base_branch base_ref
  project_name="$(basename "$repo_root")"
  task_slug="$(slugify_worktree_label "$task_text")"
  [ -n "$task_slug" ] || task_slug="ad-hoc"
  branch_prefix="$(branch_prefix_for_task "$task_text")"
  branch_name="$branch_prefix/$task_slug"
  wt_dir="${repo_root}/../${project_name}-${branch_prefix}-${task_slug}"

  if [ -d "$wt_dir" ]; then
    printf '%s\n' "$wt_dir"
    return 0
  fi

  base_branch="$(resolve_base_branch "$repo_root")" \
    || fail "could not resolve default branch for task worktree"
  base_ref="$base_branch"
  if git -C "$repo_root" rev-parse --verify "origin/$base_branch" >/dev/null 2>&1; then
    base_ref="origin/$base_branch"
  fi

  printf 'creating worktree\n' >&2
  printf 'worktree branch: %s\n' "$branch_name" >&2
  printf 'worktree base: %s\n' "$base_ref" >&2
  printf 'worktree path: %s\n' "$wt_dir" >&2
  git -C "$repo_root" worktree add "$wt_dir" -b "$branch_name" "$base_ref" >/dev/null 2>&1 \
    || git -C "$repo_root" worktree add "$wt_dir" "$branch_name" >/dev/null 2>&1 \
    || fail "failed to create or open worktree for branch $branch_name"

  sync_worktree_env_files "$repo_root" "$wt_dir"
  sync_worktree_memory "$repo_root" "$wt_dir"

  printf '%s\n' "$wt_dir"
}

resolve_base_branch() {
  local repo_root="${1:-.}"
  local base="" repo
  if has_command gh && gh auth status >/dev/null 2>&1; then
    repo="$(git -C "$repo_root" remote get-url origin 2>/dev/null | sed -E 's#(git@github.com:|https://github.com/)([^/:]+)[:/]([^/]+/[^/.]+)(\.git)?#\3#' || true)"
    if [ -n "$repo" ]; then
      base="$(gh repo view "$repo" --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null || true)"
    else
      base="$(cd "$repo_root" && gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name' 2>/dev/null || true)"
    fi
    if [ -n "$base" ]; then
      printf '%s\n' "$base"
      return 0
    fi
  fi
  base="$(git -C "$repo_root" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's#refs/remotes/origin/##' || true)"
  if [ -n "$base" ]; then
    printf '%s\n' "$base"
    return 0
  fi
  for candidate in main master develop; do
    if git -C "$repo_root" rev-parse --verify "origin/$candidate" >/dev/null 2>&1 || git -C "$repo_root" rev-parse --verify "$candidate" >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

resolve_pr_base_branch() {
  local base_override="${1:-}"
  local branch base repo upstream_ref
  if [ -n "$base_override" ]; then
    printf '%s\n' "$base_override"
    return 0
  fi

  if has_command gh && gh auth status >/dev/null 2>&1; then
    branch="$(current_branch)"
    if [ "$branch" != "no-git" ] && [ "$branch" != "HEAD" ]; then
      base="$(gh pr view --json baseRefName --jq '.baseRefName' 2>/dev/null || true)"
      if [ -n "$base" ]; then
        printf '%s\n' "$base"
        return 0
      fi

      repo="$(git remote get-url origin 2>/dev/null | sed -E 's#(git@github.com:|https://github.com/)([^/:]+)[:/]([^/]+/[^/.]+)(\.git)?#\3#' || true)"
      if [ -n "$repo" ]; then
        base="$(gh pr list --repo "$repo" --head "$branch" --state open --json baseRefName --jq '.[0].baseRefName' 2>/dev/null || true)"
      else
        base="$(gh pr list --head "$branch" --state open --json baseRefName --jq '.[0].baseRefName' 2>/dev/null || true)"
      fi
      if [ -n "$base" ]; then
        printf '%s\n' "$base"
        return 0
      fi
    fi
  fi

  branch="$(current_branch)"
  if [ "$branch" != "no-git" ] && [ "$branch" != "HEAD" ]; then
    upstream_ref="$(git config --get "branch.$branch.merge" 2>/dev/null || true)"
    base="${upstream_ref#refs/heads/}"
    if [ -n "$base" ] && [ "$base" != "$upstream_ref" ]; then
      printf '%s\n' "$base"
      return 0
    fi
  fi

  resolve_base_branch
}

rebase_in_progress() {
  local rebase_merge rebase_apply
  rebase_merge="$(git rev-parse --git-path rebase-merge 2>/dev/null || true)"
  rebase_apply="$(git rev-parse --git-path rebase-apply 2>/dev/null || true)"
  [ -n "$rebase_merge" ] && [ -d "$rebase_merge" ] && return 0
  [ -n "$rebase_apply" ] && [ -d "$rebase_apply" ] && return 0
  return 1
}

sync_branch_for_pr() {
  local base_override="${1:-}"
  local branch base
  branch="$(current_branch)"
  [ "$branch" != "no-git" ] || fail "not inside a git repository"
  [ "$branch" != "HEAD" ] || fail "cannot sync a detached HEAD"
  base="$(resolve_pr_base_branch "$base_override" || true)"
  [ -n "$base" ] || fail "could not determine the PR base branch"

  git config rerere.enabled true
  git config rerere.autoUpdate true
  git fetch origin --prune

  if ! git rebase --autostash "origin/$base"; then
    if rebase_in_progress; then
      fail "rebase found conflicts; resolve them manually, then run git rebase --continue and rerun pr-publish"
    fi
    fail "rebase failed"
  fi
}
