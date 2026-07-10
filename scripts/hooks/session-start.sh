#!/bin/bash
set -euo pipefail

payload="$(cat)"
task="session start"
if command -v jq >/dev/null 2>&1; then
  parsed="$(printf '%s' "$payload" | jq -r '.prompt // .user_prompt // .message // .input // .payload.prompt // .event.prompt // empty' | head -n 1)"
  [ -n "$parsed" ] && task="$parsed"
fi

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
FRAMEWORK_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
bash "$FRAMEWORK_ROOT/scripts/context-pack.sh" "$task"
