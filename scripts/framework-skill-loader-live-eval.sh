#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE="$(mktemp -d "$ROOT/.codex/skill-loader-eval.XXXXXX")"
SKILL_ROOT="$FIXTURE/.agents/skills/codex-framework-loader-canary"
RESULT="$FIXTURE/result.json"
SCHEMA="$FIXTURE/result.schema.json"
CODEX_LOG="$FIXTURE/codex.stderr"
CODEX_TRACE="$FIXTURE/codex.jsonl"
EOF_CANARY="EOF_CANARY_7C1E9D4A"
REFERENCE_CANARY="REFERENCE_CANARY_52B8F0C6"
FORBIDDEN_CANARY="FORBIDDEN_CANARY_9A33D271"
trap 'rm -rf -- "$FIXTURE"' EXIT

mkdir -p "$SKILL_ROOT/references"
cat > "$SKILL_ROOT/SKILL.md" <<SKILL_EOF
---
name: codex-framework-loader-canary
description: Verify the native Codex skill loader by explicitly invoking this disposable audit skill.
---

# Native loader canary

When explicitly invoked, read \`references/required.md\` and return the exact EOF and required-reference canaries using the requested JSON schema. Do not read \`references/forbidden.md\` and do not invent its contents.

The final instruction in this main skill is authoritative.
EOF canary: $EOF_CANARY
SKILL_EOF
printf 'Required reference canary: %s\n' "$REFERENCE_CANARY" > "$SKILL_ROOT/references/required.md"
printf 'This file must not be read. Secret canary: %s\n' "$FORBIDDEN_CANARY" > "$SKILL_ROOT/references/forbidden.md"

cat > "$SCHEMA" <<'EOF'
{
  "type": "object",
  "properties": {
    "eof_canary": {"type": "string"},
    "reference_canary": {"type": "string"},
    "forbidden_file_read": {"type": "boolean"}
  },
  "required": ["eof_canary", "reference_canary", "forbidden_file_read"],
  "additionalProperties": false
}
EOF

# The dollar-prefixed skill invocation is intentionally literal.
# shellcheck disable=SC2016
prompt='Explicitly use $codex-framework-loader-canary. Follow its instructions and return only the requested structured result.'
if ! codex exec --ephemeral --json -C "$FIXTURE" --sandbox read-only --output-schema "$SCHEMA" --output-last-message "$RESULT" "$prompt" >"$CODEX_TRACE" 2>"$CODEX_LOG"; then
  sed -n '1,240p' "$CODEX_LOG" >&2
  exit 1
fi

python3 - "$RESULT" "$CODEX_TRACE" "$EOF_CANARY" "$REFERENCE_CANARY" "$FORBIDDEN_CANARY" <<'PY'
import json
import sys
from pathlib import Path

path, trace_path, eof_canary, reference_canary, forbidden_canary = sys.argv[1:]
raw = Path(path).read_text()
result = json.loads(raw)
assert result == {
    "eof_canary": eof_canary,
    "reference_canary": reference_canary,
    "forbidden_file_read": False,
}, result
assert forbidden_canary not in raw
events = [json.loads(line) for line in Path(trace_path).read_text().splitlines() if line.strip()]
trace = json.dumps(events, sort_keys=True)
assert forbidden_canary not in trace, "forbidden reference content appeared in the observable tool trace"
def command_values(value):
    if isinstance(value, dict):
        for key, child in value.items():
            if key in {"command", "cmd"} and isinstance(child, str):
                yield child
            yield from command_values(child)
    elif isinstance(value, list):
        for child in value:
            yield from command_values(child)
commands = list(command_values(events))
assert not any("references/forbidden.md" in command for command in commands), \
    "forbidden reference appeared in an observable tool command"
PY

printf 'native skill loader canary passed: discovery, EOF, required reference, observable read trace excludes forbidden reference\n'
