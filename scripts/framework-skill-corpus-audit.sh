#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
printf 'framework-skill-corpus-audit.sh is a compatibility entrypoint; quality is conjunctive, not scored.\n'
exec python3 "$ROOT/scripts/framework-skill-quality.py" check
