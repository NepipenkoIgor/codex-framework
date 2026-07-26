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

check 'project config parses in native Codex' bash -c "codex --strict-config -C '$ROOT' --help >/dev/null"
check 'shared native agent concurrency is bounded' grep -Eq '^max_concurrent_threads_per_session = 4$' "$CONFIG"
check 'shared native agent delegation is one level deep' grep -Eq '^max_depth = 1$' "$CONFIG"
check 'no surface-specific runtime branch exists' bash -c "! rg -n -i 'surface[[:space:]]*=' '$ROOT'/scripts '$ROOT'/.codex --glob '!runs/**' --glob '!hooks/events.jsonl'"
check 'no startup prompt payload is injected' bash -c "! grep -Eq 'SessionStart|UserPromptSubmit|PostToolUse' '$CONFIG'"
check 'custom profiles inherit the current catalog model' bash -c "! rg -q '^model = ' '$ROOT/.codex/agents'"
check 'project config is machine portable' bash -c "! rg -q '/Users/|/home/' '$CONFIG'"

printf 'surface parity: %d failures\n' "$failures"
[ "$failures" -eq 0 ]
