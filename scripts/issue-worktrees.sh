#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

usage() {
  cat <<EOF
usage:
  issue-worktrees.sh list [repo-root]
  issue-worktrees.sh cleanup <issue-number> [repo-root]
  issue-worktrees.sh resume <issue-number> [repo-root]
EOF
}

issue_pattern() {
  local project_name="$1"
  local issue_number="$2"
  printf '(^|/)%s-%s($|-)|refs/heads/fix/%s($|-)' "$project_name" "$issue_number" "$issue_number"
}

worktree_mtime() {
  local path="$1"
  if stat -f '%m' "$path" >/dev/null 2>&1; then
    stat -f '%m' "$path"
  else
    stat -c '%Y' "$path"
  fi
}

worktree_dirty() {
  local path="$1"
  if [ -n "$(git -C "$path" status --porcelain 2>/dev/null || true)" ]; then
    printf 'dirty'
  else
    printf 'clean'
  fi
}

metadata_value() {
  local file="$1"
  local key="$2"
  [ -f "$file" ] || return 1
  sed -n "s/^${key}=//p" "$file" | tail -n 1
}

list_issue_worktrees() {
  local repo_root="${1:-$(project_root)}"
  local project_name path branch bare_branch issue base_branch base_sha dirty created meta
  project_name="$(basename "$repo_root")"

  git -C "$repo_root" worktree list --porcelain | awk -v project="$project_name" '
    /^worktree / {
      if (path != "") print path "|" branch
      path=substr($0, 10)
      branch=""
    }
    /^branch / { branch=substr($0, 8) }
    END { if (path != "") print path "|" branch }
  ' | while IFS='|' read -r path branch; do
    [ -n "$path" ] || continue
    meta="$path/.codex/worktree.env"
    issue="$(metadata_value "$meta" "ISSUE_NUMBER" 2>/dev/null || true)"
    if [ -z "$issue" ]; then
      case "$(basename "$path")" in
        "$project_name"-[0-9]*)
          issue="$(basename "$path" | sed -E "s/^${project_name}-([0-9]+).*/\\1/")"
          ;;
      esac
    fi
    if [ -z "$issue" ] && printf '%s\n' "$branch" | grep -Eq '^refs/heads/fix/[0-9]+'; then
      issue="$(printf '%s\n' "$branch" | sed -E 's#^refs/heads/fix/([0-9]+).*#\1#')"
    fi
    [ -n "$issue" ] || continue

    bare_branch="${branch#refs/heads/}"
    base_branch="$(metadata_value "$meta" "BASE_BRANCH" 2>/dev/null || true)"
    base_sha="$(metadata_value "$meta" "BASE_SHA" 2>/dev/null || true)"
    created="$(metadata_value "$meta" "CREATED_AT" 2>/dev/null || true)"
    dirty="$(worktree_dirty "$path")"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "$issue" "${base_sha:0:12}" "${base_branch:-unknown}" "$dirty" "$bare_branch" "$path" "${created:-unknown}" "$(worktree_mtime "$path")"
  done | sort -k1,1n -k8,8nr
}

latest_issue_worktree() {
  local issue_number="$1"
  local repo_root="${2:-$(project_root)}"
  list_issue_worktrees "$repo_root" | awk -F '\t' -v issue="$issue_number" '$1 == issue { print $6; exit }'
}

cleanup_issue_worktrees() {
  local issue_number="$1"
  local repo_root="${2:-$(project_root)}"
  local rows path branch
  rows="$(list_issue_worktrees "$repo_root" | awk -F '\t' -v issue="$issue_number" '$1 == issue')"
  [ -n "$rows" ] || {
    printf 'no issue worktrees found for %s\n' "$issue_number"
    return 0
  }

  printf '%s\n' "$rows" | while IFS=$'\t' read -r _issue _sha _base _dirty branch path _created _mtime; do
    printf 'removing worktree: %s\n' "$path"
    git -C "$repo_root" worktree remove "$path" --force
    if [ -n "$branch" ] && git -C "$repo_root" show-ref --verify --quiet "refs/heads/$branch"; then
      if git -C "$repo_root" branch --merged | sed 's/^..//' | grep -Fxq "$branch"; then
        printf 'deleting merged branch: %s\n' "$branch"
        git -C "$repo_root" branch -d "$branch" >/dev/null
      else
        printf 'keeping unmerged branch: %s\n' "$branch"
      fi
    fi
  done
}

cmd="${1:-}"
shift || true

case "$cmd" in
  list) list_issue_worktrees "${1:-$(project_root)}" ;;
  resume)
    [ $# -ge 1 ] || { usage; exit 1; }
    latest_issue_worktree "$1" "${2:-$(project_root)}"
    ;;
  cleanup)
    [ $# -ge 1 ] || { usage; exit 1; }
    cleanup_issue_worktrees "$1" "${2:-$(project_root)}"
    ;;
  help|-h|--help|"") usage ;;
  *) usage; exit 1 ;;
esac
