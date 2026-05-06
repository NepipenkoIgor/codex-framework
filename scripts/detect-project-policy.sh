#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

ROOT="${1:-$PWD}"
stack="$(bash "$(framework_root)/scripts/detect-project-stack.sh" "$ROOT" 2>/dev/null || echo "unknown")"
features="$(bash "$(framework_root)/scripts/detect-project-features.sh" "$ROOT" 2>/dev/null || echo "none")"

policy=""

add_policy() {
  policy="$(append_unique_csv "$policy" "$1")"
}

has_file() {
  [ -f "$ROOT/$1" ]
}

tree_has() {
  local pattern="$1"
  search_project_tree_regex "$pattern" "$ROOT"
}

stack_has "$stack" "tailwind" && add_policy "tailwind-first"
printf '%s' "$features" | grep -Eq '(^|,)tailwind(,|$)' && add_policy "tailwind-first"
printf '%s' "$features" | grep -Eq '(^|,)utility-classes(,|$)' && add_policy "utility-classes"
printf '%s' "$features" | grep -Eq '(^|,)variants(,|$)' && add_policy "variant-system"
printf '%s' "$features" | grep -Eq '(^|,)ui-primitives(,|$)' && add_policy "ui-primitives"

if tree_has 'className=.*\bcn\('; then
  add_policy "use-cn-helper"
fi

if find "$ROOT" -type d \( -path '*/components/ui' -o -path '*/src/components/ui' \) | grep -q .; then
  add_policy "prefer-shared-ui-components"
fi

if tree_has 'style=\{\{' && stack_has "$stack" "tailwind"; then
  add_policy "avoid-inline-styles"
fi

if tree_has 'class-variance-authority|cva\('; then
  add_policy "prefer-cva-variants"
fi

if [ -f "$ROOT/package.json" ]; then
  search_file_regex '"vitest"' "$ROOT/package.json" && add_policy "tests-vitest"
  search_file_regex '"eslint"|eslintConfig' "$ROOT/package.json" && add_policy "lint-eslint"
fi

if [ -z "$policy" ]; then
  printf 'none\n'
else
  printf '%s\n' "$policy"
fi
