#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

ROOT="${1:-$(project_root)}"
FRAMEWORK_ROOT="$(framework_root)"

print_section "Doctor"
info "root: $ROOT"
info "framework: $FRAMEWORK_ROOT"

print_section "Dependencies"
missing="$(detect_missing_deps)"
if [ "$missing" = "none" ]; then
  info "all core dependencies present"
else
  printf 'missing=%s\n' "$missing"
fi

print_section "Permissions"
info "runtime-controlled: yes"
info "framework can reduce approval prompts but cannot self-grant broader access"
if [ -w "$ROOT" ]; then
  info "workspace writable: yes"
else
  warn "workspace writable: no"
fi
info "preferred low-friction commands: codex-fw doctor | brief | plan | post-change-check | guard-scan"
info "see: $FRAMEWORK_ROOT/CODEX.permissions.md"

print_section "Capabilities"
bash "$FRAMEWORK_ROOT/scripts/capabilities.sh" "$ROOT"

print_section "Project Bootstrap"
if [ -f "$ROOT/CODEX.md" ]; then
  info "project instructions: present"
else
  warn "project instructions: missing"
fi
if [ -f "$ROOT/.codex/project.env" ]; then
  info "command registry: present"
else
  warn "command registry: missing"
fi
effective_cache="$(project_cache_dir)"
if [ -d "$effective_cache" ]; then
  info "cache dir: $effective_cache"
else
  warn "cache dir unavailable"
fi
intelligence_file="$(cached_repo_intelligence_file)"
if [ -f "$intelligence_file" ]; then
  info "repo intelligence: $intelligence_file"
  if repo_intelligence_stale "$intelligence_file"; then
    warn "repo intelligence status: stale"
  else
    info "repo intelligence status: fresh"
  fi
fi

print_section "Hook Runtime"
bash "$FRAMEWORK_ROOT/scripts/hooks.sh" doctor "$ROOT" || true
info "git hooks: project-owned; Codex runtime hooks are framework-generated local adapters"

print_section "Framework Files"
for required in CODEX.md CODEX.concepts.md CODEX.skills.md CODEX.capabilities.md CODEX.permissions.md ORCHESTRATOR_REFERENCE.md README.md scripts/codex-fw.sh scripts/framework-health.sh scripts/detect-project-features.sh; do
  if [ -e "$FRAMEWORK_ROOT/$required" ]; then
    info "$required: present"
  else
    warn "$required: missing"
  fi
done
