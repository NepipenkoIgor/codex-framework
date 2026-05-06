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

test_plan_lines_from_spec() {
  local spec_file="$1"
  [ -f "$spec_file" ] || return 1
  awk -F'|' '
    /^\|[[:space:]]*[0-9]+[[:space:]]*\|/ {
      requirement=$3
      status=$5
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", requirement)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", status)
      if (status ~ /✓/) {
        print "- ✓ " requirement
      } else if (status ~ /✗/) {
        print "- ✗ " requirement " (failing)"
      } else if (status ~ /☐/) {
        print "- ☐ " requirement " (unverified)"
      }
    }
  ' "$spec_file"
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

verification_lines() {
  local emitted=0
  local hook_names=""
  local common_dir hook_file hook_name
  local report_file lint_status lint_cmd tests_status tests_cmd build_status build_cmd

  report_file="$(run_root)/latest-pr-ready.env"
  if [ -f "$report_file" ]; then
    # shellcheck disable=SC1090
    . "$report_file"
  fi

  lint_status="${check_lint_status:-}"
  lint_cmd="${check_lint_cmd:-${LINT_CMD:-}}"
  tests_status="${check_tests_status:-}"
  tests_cmd="${check_tests_cmd:-${TEST_CMD:-}}"
  build_status="${check_build_status:-}"
  build_cmd="${check_build_cmd:-${BUILD_CMD:-}}"

  if [ -n "$lint_cmd" ]; then
    case "$lint_status" in
      passed) printf -- '- ✓ Lint passed: `%s`\n' "$lint_cmd" ;;
      failed) printf -- '- ✗ Lint failed: `%s`\n' "$lint_cmd" ;;
      *) printf -- '- ☐ Lint not run: `%s`\n' "$lint_cmd" ;;
    esac
    emitted=1
  fi

  if [ -n "$tests_cmd" ]; then
    case "$tests_status" in
      passed) printf -- '- ✓ Tests passed: `%s`\n' "$tests_cmd" ;;
      failed) printf -- '- ✗ Tests failed: `%s`\n' "$tests_cmd" ;;
      *) printf -- '- ☐ Tests not run: `%s`\n' "$tests_cmd" ;;
    esac
    emitted=1
  fi

  if [ -n "$build_cmd" ]; then
    case "$build_status" in
      passed) printf -- '- ✓ Build passed: `%s`\n' "$build_cmd" ;;
      failed) printf -- '- ✗ Build failed: `%s`\n' "$build_cmd" ;;
      *) printf -- '- ☐ Build not run: `%s`\n' "$build_cmd" ;;
    esac
    emitted=1
  fi

  if [ -d "$ROOT/.husky" ] || [ -f "$ROOT/lefthook.yml" ] || [ -f "$ROOT/lefthook.yaml" ] || package_json_has_key "simple-git-hooks" || [ -d "$ROOT/.github/hooks" ]; then
    printf -- '- ☐ Repository hooks are configured; let them run before landing the change\n'
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
    printf -- '- ☐ Installed git hooks detected: `%s`\n' "$hook_names"
    emitted=1
  fi

  if [ "${emitted}" -eq 0 ]; then
    if package_json_has_script "test:watch"; then
      printf -- '- ☐ Do a targeted manual check and verify the result in the app\n'
    else
      printf -- '- ☐ Do a targeted manual check\n'
    fi
  fi
}

base_branch="$(resolve_pr_base_branch || true)"
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

test_plan_lines=""
if [ -n "$spec_file" ]; then
  test_plan_lines="$(test_plan_lines_from_spec "$spec_file" || true)"
fi
verification_lines="$(verification_lines)"
if [ -n "$test_plan_lines" ]; then
  test_plan_lines="$test_plan_lines
$verification_lines"
else
  test_plan_lines="$verification_lines"
fi

if [ -z "$OUTPUT_FILE" ]; then
  OUTPUT_FILE="$(run_root)/$(date -u +"%Y%m%dT%H%M%SZ")-pr-body.md"
fi

cat > "$OUTPUT_FILE" <<EOF
## Summary
$summary_lines

## Test Plan
$test_plan_lines
EOF

printf '%s\n' "$OUTPUT_FILE"
