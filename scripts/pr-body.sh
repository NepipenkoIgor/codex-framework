#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

usage() {
  cat <<EOF
usage: pr-body.sh [--output <file>]
EOF
}

OUTPUT_FILE=""

while [ $# -gt 0 ]; do
  case "$1" in
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

ROOT="$(project_root)"
ensure_project_bootstrap "$ROOT"
load_project_commands
cd "$ROOT"

git rev-parse --show-toplevel >/dev/null 2>&1 || fail "not inside a git repository"

resolve_base_branch() {
  local base=""
  base="$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's#refs/remotes/origin/##' || true)"
  if [ -n "$base" ]; then
    printf '%s\n' "$base"
    return 0
  fi
  for candidate in main master develop; do
    if git rev-parse --verify "origin/$candidate" >/dev/null 2>&1 || git rev-parse --verify "$candidate" >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

normalize_subject() {
  printf '%s\n' "$1" | sed -E 's/^(feat|fix|refactor|test|chore|docs|style|perf)(\([^)]+\))?:[[:space:]]*//'
}

summary_lines_from_commits() {
  local merge_base="$1"
  git log --format=%s "$merge_base..HEAD" 2>/dev/null | sed '/^[[:space:]]*$/d' | head -n 5 | while IFS= read -r subject; do
    printf -- '- %s\n' "$(normalize_subject "$subject")"
  done
}

summary_lines_from_spec() {
  local spec_file="$1"
  [ -f "$spec_file" ] || return 1
  awk -F'|' '
    /^\|[[:space:]]*[0-9]+[[:space:]]*\|/ {
      status=$5
      requirement=$3
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", status)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", requirement)
      if (status ~ /✓/) {
        print "- " requirement
      }
    }
  ' "$spec_file" | head -n 5
}

summary_lines_from_diff() {
  git diff --name-only HEAD 2>/dev/null | head -n 5 | while IFS= read -r file; do
    [ -n "$file" ] || continue
    printf -- '- Update %s\n' "$file"
  done
}

package_json_has_key() {
  local key="$1"
  [ -f "$ROOT/package.json" ] || return 1
  python3 - <<PY >/dev/null 2>&1
import json, sys
with open("$ROOT/package.json", "r", encoding="utf-8") as f:
    data = json.load(f)
sys.exit(0 if "$key" in data else 1)
PY
}

package_json_has_script() {
  local key="$1"
  [ -f "$ROOT/package.json" ] || return 1
  python3 - <<PY >/dev/null 2>&1
import json, sys
with open("$ROOT/package.json", "r", encoding="utf-8") as f:
    data = json.load(f)
scripts = data.get("scripts", {})
sys.exit(0 if "$key" in scripts else 1)
PY
}

hook_plan_lines() {
  local emitted=0
  local hook_names=""
  local common_dir hooks_path hook_file hook_name

  if [ -d "$ROOT/.husky" ]; then
    printf -- '- [ ] Git hooks via Husky\n'
    emitted=1
  fi

  if [ -f "$ROOT/lefthook.yml" ] || [ -f "$ROOT/lefthook.yaml" ]; then
    printf -- '- [ ] Git hooks via Lefthook\n'
    emitted=1
  fi

  if package_json_has_key "simple-git-hooks"; then
    printf -- '- [ ] Git hooks via simple-git-hooks\n'
    emitted=1
  fi

  if [ -d "$ROOT/.github/hooks" ]; then
    printf -- '- [ ] Repository hook scripts from .github/hooks\n'
    emitted=1
  fi

  hooks_path="$(git config core.hooksPath 2>/dev/null || true)"
  if [ -n "$hooks_path" ]; then
    printf -- '- [ ] Git hooks from core.hooksPath (`%s`)\n' "$hooks_path"
    emitted=1
  fi

  common_dir="$(git rev-parse --git-common-dir 2>/dev/null || true)"
  if [ -n "$common_dir" ] && [ -d "$common_dir/hooks" ]; then
    for hook_file in "$common_dir/hooks"/pre-commit "$common_dir/hooks"/commit-msg "$common_dir/hooks"/pre-push; do
      [ -x "$hook_file" ] || continue
      hook_name="$(basename "$hook_file")"
      if [ -z "$hook_names" ]; then
        hook_names="$hook_name"
      else
        hook_names="$hook_names, $hook_name"
      fi
    done
  fi

  if [ -n "$hook_names" ]; then
    printf -- '- [ ] Installed git hooks: %s\n' "$hook_names"
    emitted=1
  fi

  return $(( emitted == 0 ))
}

command_plan_lines() {
  local emitted=0
  for cmd in "${TEST_CMD:-}" "${LINT_CMD:-}" "${BUILD_CMD:-}"; do
    [ -n "$cmd" ] || continue
    printf -- '- [ ] `%s`\n' "$cmd"
    emitted=1
  done
  return $(( emitted == 0 ))
}

manual_plan_lines() {
  if package_json_has_script "test:watch"; then
    printf -- '- [ ] Targeted manual verification in addition to configured hooks/scripts\n'
  else
    printf -- '- [ ] Targeted manual verification\n'
  fi
}

verification_lines() {
  if hook_plan_lines; then
    return 0
  fi
  if command_plan_lines; then
    return 0
  fi
  manual_plan_lines
}

base_branch="$(resolve_base_branch || true)"
merge_base=""
if [ -n "$base_branch" ]; then
  merge_base="$(git merge-base HEAD "origin/$base_branch" 2>/dev/null || git merge-base HEAD "$base_branch" 2>/dev/null || true)"
fi

summary_lines=""
spec_file="$(active_spec_file || true)"
if [ -n "$spec_file" ]; then
  summary_lines="$(summary_lines_from_spec "$spec_file" || true)"
fi
if [ -z "$summary_lines" ] && [ -n "$merge_base" ]; then
  summary_lines="$(summary_lines_from_commits "$merge_base" || true)"
fi
if [ -z "$summary_lines" ]; then
  summary_lines="$(summary_lines_from_diff || true)"
fi
if [ -z "$summary_lines" ]; then
  summary_lines='- Update the implementation in this branch'
fi

if [ -z "$OUTPUT_FILE" ]; then
  OUTPUT_FILE="$(run_root)/$(date -u +"%Y%m%dT%H%M%SZ")-pr-body.md"
fi

cat > "$OUTPUT_FILE" <<EOF
## Summary
$summary_lines

## Test Plan
$(verification_lines)
EOF

printf '%s\n' "$OUTPUT_FILE"
