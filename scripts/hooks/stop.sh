#!/bin/bash
set -euo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$root"

changed="$(git diff --name-only HEAD)"
[ -n "$changed" ] || exit 0

git diff --check
