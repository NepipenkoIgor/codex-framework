#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARTIFACT_DIR="${SKILL_QUALITY_ARTIFACT_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/codex-skill-quality.XXXXXX")}"
exec python3 "$ROOT/scripts/framework-skill-quality.py" routing-live --artifact-dir "$ARTIFACT_DIR" "$@"
