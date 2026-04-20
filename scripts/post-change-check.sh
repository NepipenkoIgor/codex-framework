#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

ROOT="$(project_root)"
ensure_project_bootstrap "$ROOT"
load_project_commands
cd "$ROOT"

changed="$(git_changed_files || true)"
if [ -z "$changed" ]; then
  info "no changed files detected"
  exit 0
fi

print_section "Changed Files"
printf '%s\n' "$changed"

need_frontend=false
need_backend=false
need_infra=false
need_docs=false

while IFS= read -r file; do
  case "$file" in
    *.ts|*.tsx|*.js|*.jsx|*.css|*.scss|*.html) need_frontend=true ;;
    *.py|*.go|*.cs|*.java|*.kt|*.rs) need_backend=true ;;
    *.yml|*.yaml|*.tf|*.tfvars|Dockerfile|docker-compose*) need_infra=true ;;
    *.md) need_docs=true ;;
  esac
done <<EOF
$changed
EOF

print_section "Suggested Checks"
if [ "$need_frontend" = true ] || [ "$need_backend" = true ]; then
  info "diagnostics"
fi
if [ "$need_frontend" = true ] && [ -n "${TEST_CMD:-}" ]; then
  run_named_command "targeted tests" "$TEST_CMD"
fi
if [ "$need_backend" = true ] && [ -n "${TEST_CMD:-}" ]; then
  run_named_command "backend checks" "$TEST_CMD"
fi
if [ "$need_frontend" = true ] && [ -n "${LINT_CMD:-}" ]; then
  run_named_command "lint" "$LINT_CMD"
fi
if [ "$need_infra" = true ] && [ -n "${BUILD_CMD:-}" ]; then
  run_named_command "infra validation" "$BUILD_CMD"
fi
if [ "$need_docs" = true ] && [ "$need_frontend" = false ] && [ "$need_backend" = false ] && [ "$need_infra" = false ]; then
  info "docs-only change: manual content review"
fi
