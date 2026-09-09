#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/.codex/config.toml"
failures=0

check() {
  local label="$1"
  shift
  if "$@"; then
    printf 'ok %s\n' "$label"
  else
    printf 'drift: %s\n' "$label"
    failures=$((failures + 1))
  fi
}

check 'project config parses in native Codex' bash -c "codex app-server --strict-config --stdio </dev/null >/dev/null 2>&1"
check 'strict config validation rejects unknown keys' bash -c "! codex app-server --strict-config -c agents.definitely_not_real=1 --stdio </dev/null >/dev/null 2>&1"
if git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  check 'project config is eligible for source control, not ignored local state' bash -c "! git -C '$ROOT' check-ignore -q .codex/config.toml"
fi
check 'shared native agent concurrency is bounded' grep -Eq '^max_concurrent_threads_per_session = 4$' "$CONFIG"
check 'tool output retention is bounded' grep -Eq '^tool_output_token_limit = 4000$' "$CONFIG"
check 'native-default optimization pins are absent' bash -c "! grep -Eq '^(web_search|enable_request_compression|remote_compaction_v2|skill_search)[[:space:]]*=' '$CONFIG'"
check 'native Codex owns agent delegation depth' bash -c "! grep -Eq '^max_depth[[:space:]]*=' '$CONFIG'"
check 'no surface-specific runtime branch exists' bash -c "! rg -n -i 'surface[[:space:]]*=' '$ROOT'/scripts '$ROOT'/.codex --glob '!runs/**' --glob '!hooks/events.jsonl'"
check 'no startup prompt payload is injected' bash -c "! grep -Eq 'SessionStart|UserPromptSubmit|PostToolUse' '$CONFIG'"
check 'custom profiles inherit the current catalog model' bash -c "! rg -q '^model = ' '$ROOT/.codex/agents'"
check 'routine tester inherits native reasoning selection' bash -c "! rg -q '^model_reasoning_effort = ' '$ROOT/.codex/agents/tester.toml'"
check 'project config is machine portable' bash -c "! rg -q '/Users/|/home/' '$CONFIG'"

printf 'surface parity: %d failures\n' "$failures"
[ "$failures" -eq 0 ]
