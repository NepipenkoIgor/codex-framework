#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

ROOT="${1:-$PWD}"
TASK="${2:-}"
task_lc="$(printf '%s' "$TASK" | tr '[:upper:]' '[:lower:]')"
stack="$(bash "$(framework_root)/scripts/detect-project-stack.sh" "$ROOT" 2>/dev/null || echo "unknown")"
features="$(bash "$(framework_root)/scripts/detect-project-features.sh" "$ROOT" 2>/dev/null || echo "none")"
policy="$(bash "$(framework_root)/scripts/detect-project-policy.sh" "$ROOT" 2>/dev/null || echo "none")"

say_present() {
  local label="$1"
  local pattern="$2"
  local glob="${3:-}"
  if search_project_tree_regex "$pattern" "$ROOT" "$glob"; then
    printf '%s\n' "$label"
  fi
}

project_file_list() {
  if command -v rg >/dev/null 2>&1; then
    if is_framework_repo_root "$ROOT"; then
      rg --files "$ROOT" \
        -g '!skills/**' -g '!agents/**' -g '!templates/**' -g '!scripts/**' \
        -g '!CODEX*.md' -g '!CONCEPTS.md' -g '!ORCHESTRATOR_REFERENCE.md' \
        -g '!README.md' -g '!SKILLS_MAP*.md'
    else
      rg --files "$ROOT"
    fi
  else
    find "$ROOT" -type f | sed "s#^$ROOT/##"
  fi
}

find_first_path() {
  local pattern="$1"
  project_file_list | grep -E "$pattern" | head -n 1
}

neighbor_files() {
  local files=()
  local path

  for path in \
    "$(find_first_path '(^|/)(tailwind\.config\.(js|cjs|mjs|ts))$')" \
    "$(find_first_path '(^|/)(src/)?app/globals\.css$')" \
    "$(find_first_path '(^|/)(src/)?lib/utils\.(ts|tsx|js)$')" \
    "$(find_first_path '(^|/)(src/)?components/ui/.*\.(tsx|ts|jsx|js)$')" \
    "$(find_first_path '(^|/)(src/)?components/.*/__tests__/.*\.(test|spec)\.(tsx|ts|jsx|js)$')" \
    "$(find_first_path '(^|/)(src/)?test/.*\.(tsx|ts|jsx|js)$')"
  do
    [ -n "$path" ] || continue
    files+=("$path")
  done

  if printf '%s' "$task_lc" | grep -Eq 'landing|hero|avatar|section|copy|page|component'; then
    while IFS= read -r path; do
      [ -n "$path" ] || continue
      files+=("$path")
    done <<EOF
$(project_file_list | grep -E '(^|/)(src/)?components/.*(landing|hero|avatar|section|page|card).*\.(tsx|ts|jsx|js)$' | head -n 5)
EOF
  fi

  printf '%s\n' "${files[@]-}" | awk 'NF && !seen[$0]++'
}

printf 'stack=%s\n' "$stack"
printf 'features=%s\n' "$features"
printf 'policy=%s\n' "$policy"

print_section "Conventions"
say_present "use-cn-helper" '\bcn\(' '*.{ts,tsx,js,jsx}'
say_present "use-cva-variants" '\bcva\(' '*.{ts,tsx,js,jsx}'
say_present "use-zod-validation" '\bzod\b|from .zod' '*.{ts,tsx,js,jsx}'
say_present "use-react-hook-form" 'react-hook-form' '*.{ts,tsx,js,jsx}'
say_present "use-testing-library" '@testing-library/' '*.{ts,tsx,js,jsx}'
say_present "use-msw" '\bmsw\b|from .msw' '*.{ts,tsx,js,jsx}'
say_present "use-server-actions" '\buse server\b|Server Action' '*.{ts,tsx}'
say_present "use-route-handlers" 'export (async )?(function )?(GET|POST|PUT|PATCH|DELETE)' '*.{ts,tsx}'
say_present "use-problem-details" 'ProblemDetails|problem\+json' '*.{cs,ts,tsx,js}'
say_present "use-structured-logging" '\blogger\b|pino|serilog|structured log' '*.{ts,tsx,js,cs}'

print_section "Neighbor Files"
neighbors="$(neighbor_files)"
if [ -n "$neighbors" ]; then
  printf '%s\n' "$neighbors"
else
  printf 'none\n'
fi
