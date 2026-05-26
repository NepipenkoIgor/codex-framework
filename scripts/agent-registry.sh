#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

usage() {
  cat <<EOF
usage: agent-registry.sh <list| get <agent> [field] | validate | prompt <agent> --task "<task>" [--skills <csv>] [--ownership <scope>] [--handoff <id>]>
EOF
}

ROOT="$(framework_root)"
REGISTRY="$ROOT/agents/registry.tsv"

registry_rows() {
  [ -f "$REGISTRY" ] || fail "missing $REGISTRY"
  awk -F '\t' 'NF && $1 !~ /^#/ && $1 != "agent" { print }' "$REGISTRY"
}

roles_from_routing() {
  awk '
    $1 == "roles:" { in_roles=1; next }
    in_roles && $1 == "verification:" { in_roles=0 }
    in_roles && $0 ~ /^  [a-z0-9-]+:$/ { gsub(":", "", $1); print $1 }
  ' "$ROOT/routing.yaml"
}

agent_row() {
  local agent="$1"
  registry_rows | awk -F '\t' -v agent="$agent" '$1 == agent { print; found=1 } END { exit found ? 0 : 1 }'
}

agent_field() {
  local agent="$1"
  local field="$2"
  local index
  case "$field" in
    agent|name) index=1 ;;
    runtime_type) index=2 ;;
    work_mode) index=3 ;;
    parallel_safe) index=4 ;;
    ownership_required) index=5 ;;
    summary) index=6 ;;
    *) fail "unknown agent field: $field" ;;
  esac
  agent_row "$agent" | awk -F '\t' -v index="$index" '{ print $index }'
}

validate_bool() {
  case "$1" in
    true|false) return 0 ;;
    *) return 1 ;;
  esac
}

validate_registry() {
  local failures=0
  local role row runtime mode parallel ownership summary seen_roles

  [ -f "$REGISTRY" ] || {
    printf 'agent registry missing: %s\n' "$REGISTRY"
    return 1
  }

  while IFS= read -r role; do
    [ -n "$role" ] || continue
    if ! agent_row "$role" >/dev/null 2>&1; then
      printf 'agent registry missing routing role: %s\n' "$role"
      failures=$((failures + 1))
    fi
  done < <(roles_from_routing)

  seen_roles="$(mktemp)"
  while IFS=$'\t' read -r role runtime mode parallel ownership summary; do
    [ -n "$role" ] || continue
    if grep -qx "$role" "$seen_roles"; then
      printf 'agent registry duplicate role: %s\n' "$role"
      failures=$((failures + 1))
    fi
    printf '%s\n' "$role" >> "$seen_roles"

    [ -f "$ROOT/agents/$role.md" ] || {
      printf 'agent brief missing for registry role: %s\n' "$role"
      failures=$((failures + 1))
    }
    grep -q '^recommended_skills:' "$ROOT/agents/$role.md" 2>/dev/null || {
      printf 'agent brief missing recommended_skills: %s\n' "$role"
      failures=$((failures + 1))
    }

    case "$runtime" in
      default|explorer|worker) ;;
      *)
        printf 'agent %s has invalid runtime_type: %s\n' "$role" "$runtime"
        failures=$((failures + 1))
        ;;
    esac

    case "$mode" in
      read-only|edit|test|plan|coordinate) ;;
      *)
        printf 'agent %s has invalid work_mode: %s\n' "$role" "$mode"
        failures=$((failures + 1))
        ;;
    esac

    validate_bool "$parallel" || {
      printf 'agent %s has invalid parallel_safe: %s\n' "$role" "$parallel"
      failures=$((failures + 1))
    }
    validate_bool "$ownership" || {
      printf 'agent %s has invalid ownership_required: %s\n' "$role" "$ownership"
      failures=$((failures + 1))
    }

    if [ "$mode" = "read-only" ] && [ "$runtime" = "worker" ]; then
      printf 'read-only agent %s must not use worker runtime\n' "$role"
      failures=$((failures + 1))
    fi
    if [ "$mode" = "read-only" ] && [ "$ownership" != "false" ]; then
      printf 'read-only agent %s must not require write ownership\n' "$role"
      failures=$((failures + 1))
    fi
    if [ -z "${summary:-}" ]; then
      printf 'agent %s missing summary\n' "$role"
      failures=$((failures + 1))
    fi
  done < <(registry_rows)
  rm -f "$seen_roles"

  if [ "$failures" -ne 0 ]; then
    printf 'agent registry validation: %d failures\n' "$failures"
    return 1
  fi

  printf 'agent registry validation passed\n'
}

prompt_agent() {
  local agent="$1"
  shift || true
  local task=""
  local skills="none"
  local ownership="unassigned"
  local handoff="none"
  while [ $# -gt 0 ]; do
    case "$1" in
      --task)
        task="${2:-}"
        shift 2
        ;;
      --skills)
        skills="${2:-none}"
        shift 2
        ;;
      --ownership)
        ownership="${2:-unassigned}"
        shift 2
        ;;
      --handoff)
        handoff="${2:-none}"
        shift 2
        ;;
      *)
        usage
        exit 1
        ;;
    esac
  done

  [ -n "$task" ] || fail "missing --task"
  agent_row "$agent" >/dev/null || fail "unknown named agent: $agent"

  local runtime mode parallel ownership_required summary role_file
  runtime="$(agent_field "$agent" runtime_type)"
  mode="$(agent_field "$agent" work_mode)"
  parallel="$(agent_field "$agent" parallel_safe)"
  ownership_required="$(agent_field "$agent" ownership_required)"
  summary="$(agent_field "$agent" summary)"
  role_file="$ROOT/agents/$agent.md"

  cat <<EOF
Named agent: $agent
Runtime spawn_agent.agent_type: $runtime
Work mode: $mode
Parallel safe: $parallel
Ownership required: $ownership_required
Summary: $summary

Task:
$task

Skills to use lazily:
$skills

Ownership:
$ownership

Handoff state:
$handoff

Operating rules:
- You are not alone in this codebase. Do not revert or overwrite work made by others.
- Respect the ownership scope. If it is unassigned and ownership is required, ask the main session for a file or responsibility boundary before editing.
- Keep the main session as coordinator; report decisions, blockers, changed files, and verification clearly.
- Treat skills as lazy context: load only the skill bodies needed for this task.
- Leave unrelated changes intact.
- If work_mode is read-only, do not edit files.
- If work_mode is edit or test, make narrow changes and run targeted verification.

Role brief:
$(cat "$role_file")
EOF
}

cmd="${1:-}"
[ -n "$cmd" ] || {
  usage
  exit 1
}
shift || true

case "$cmd" in
  list)
    printf 'agent\truntime_type\twork_mode\tparallel_safe\townership_required\tsummary\n'
    registry_rows
    ;;
  get)
    agent="${1:-}"
    field="${2:-}"
    [ -n "$agent" ] || fail "missing agent"
    agent_row "$agent" >/dev/null || fail "unknown named agent: $agent"
    if [ -n "$field" ]; then
      agent_field "$agent" "$field"
    else
      printf 'agent=%s\n' "$agent"
      printf 'runtime_type=%s\n' "$(agent_field "$agent" runtime_type)"
      printf 'work_mode=%s\n' "$(agent_field "$agent" work_mode)"
      printf 'parallel_safe=%s\n' "$(agent_field "$agent" parallel_safe)"
      printf 'ownership_required=%s\n' "$(agent_field "$agent" ownership_required)"
      printf 'summary=%s\n' "$(agent_field "$agent" summary)"
    fi
    ;;
  validate)
    validate_registry
    ;;
  prompt)
    agent="${1:-}"
    [ -n "$agent" ] || fail "missing agent"
    shift || true
    prompt_agent "$agent" "$@"
    ;;
  -h|--help)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
