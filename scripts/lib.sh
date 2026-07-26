#!/bin/bash
set -euo pipefail

framework_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

project_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

fail() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

has_command() {
  command -v "$1" >/dev/null 2>&1
}

git_changed_files() {
  git rev-parse --show-toplevel >/dev/null 2>&1 || return 0
  {
    git diff --name-only HEAD
    git ls-files --others --exclude-standard
  } | awk 'NF && !seen[$0]++'
}

timestamp_utc() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

csv_from_lines() {
  awk 'NF { gsub(/^[[:space:]]+|[[:space:]]+$/, ""); if ($0 != "") { if (out != "") out = out ","; out = out $0 } } END { print out }'
}
