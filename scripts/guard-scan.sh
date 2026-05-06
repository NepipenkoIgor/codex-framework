#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

usage() {
  cat <<EOF
usage: guard-scan.sh [--staged | --changed | --all] [file ...]
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
    staged)
      git diff --cached --name-only
      ;;
    changed)
      git_changed_files
      ;;
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
  info "guard scan: no files selected"
  exit 0
fi

violations=0
print_section "Guard Scan"

for file in "${files[@]}"; do
  [ -f "$file" ] || continue
  case "$file" in
    *.png|*.jpg|*.jpeg|*.gif|*.pdf|*.zip|*.lock|*.woff|*.woff2|*.ttf|*.ico)
      continue
      ;;
  esac

  content="$(sed -n '1,240p' "$file" 2>/dev/null || true)"
  result="$(scan_text_for_policy_violations "$content")"
  if [ "$result" != "none" ]; then
    printf 'blocked: %s -> %s\n' "$file" "$result"
    violations=$((violations + 1))
  fi
  case "$file" in
    *.tsx|*.jsx|*.vue|*.astro)
      if { stack_has "$stack" "tailwind" || printf '%s' "$policy" | grep -Eq '(^|,)tailwind-first(,|$)'; } \
        && printf '%s' "$content" | grep -Eq 'style=\{\{' \
        && ! printf '%s' "$content" | grep -Eq 'codex-allow-inline-style'; then
        printf 'blocked: %s -> inline-style-tailwind\n' "$file"
        violations=$((violations + 1))
      fi
      ;;
  esac
done

if [ "$violations" -ne 0 ]; then
  exit 1
fi

info "guard scan passed"
