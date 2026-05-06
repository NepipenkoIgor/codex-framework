#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

usage() {
  cat <<EOF
usage: quality-check.sh [--staged | --changed | --all] [file ...]
EOF
}

ROOT="$(project_root)"
cd "$ROOT"
stack="$(cached_stack_summary)"
policy="$(cached_policy_summary)"
mode="changed"
files=()

while [ $# -gt 0 ]; do
  case "$1" in
    --staged) mode="staged" ;;
    --changed) mode="changed" ;;
    --all) mode="all" ;;
    -h|--help) usage; exit 0 ;;
    *) files+=("$1") ;;
  esac
  shift
done

collect_files() {
  case "$mode" in
    staged) git diff --cached --name-only ;;
    changed) git_changed_files ;;
    all)
      find . -type f \
        -not -path '*/.git/*' \
        -not -path '*/node_modules/*' \
        -not -path '*/dist/*' \
        -not -path '*/build/*' \
        -not -path '*/coverage/*' \
        | sed 's#^\./##'
      ;;
  esac
}

if [ "${#files[@]}" -eq 0 ]; then
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    files+=("$file")
  done <<EOF
$(collect_files)
EOF
fi

if [ "${#files[@]}" -eq 0 ]; then
  info "quality check: no files selected"
  exit 0
fi

violations=0
print_section "Quality Check"

for file in "${files[@]}"; do
  [ -f "$file" ] || continue
  case "$file" in
    *.tsx|*.jsx|*.ts|*.js|*.css|*.scss) ;;
    *) continue ;;
  esac

  content="$(sed -n '1,260p' "$file" 2>/dev/null || true)"

  if { stack_has "$stack" "tailwind" || printf '%s' "$policy" | grep -Eq '(^|,)tailwind-first(,|$)'; } \
    && printf '%s' "$content" | grep -Eq '#[0-9A-Fa-f]{3,8}|rgb(a)?\('; then
    printf 'warn: %s -> hardcoded-color-literal\n' "$file"
    violations=$((violations + 1))
  fi

  if printf '%s' "$policy" | grep -Eq '(^|,)use-cn-helper(,|$)' \
    && printf '%s' "$content" | grep -Eq 'className=\{[`"'"'"']' \
    && ! printf '%s' "$content" | grep -Eq '\bcn\('; then
    printf 'warn: %s -> missing-cn-helper\n' "$file"
    violations=$((violations + 1))
  fi

  if printf '%s' "$policy" | grep -Eq '(^|,)use-cva-variants(,|$)' \
    && printf '%s' "$content" | grep -Eq 'className=.*(rounded-|px-|py-|text-|bg-|border-|shadow-).*(rounded-|px-|py-|text-|bg-|border-|shadow-)'; then
    printf 'warn: %s -> consider-cva-or-shared-variant\n' "$file"
  fi
done

if [ "$violations" -ne 0 ]; then
  exit 1
fi

info "quality check passed"
