#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

[ $# -ge 1 ] || fail "usage: github-issue-fetch.sh <issue-number-or-url>"

ref="$1"

if ! has_command gh; then
  fail "gh CLI is required"
fi

if ! gh auth status >/dev/null 2>&1; then
  fail "gh auth is required"
fi

if printf '%s' "$ref" | grep -Eq '^[0-9]+$'; then
  gh issue view "$ref" --json number,title,url,body,comments
elif printf '%s' "$ref" | grep -Eq 'github\.com/.*/issues/[0-9]+'; then
  issue_number="$(printf '%s' "$ref" | grep -oE '/issues/[0-9]+' | grep -oE '[0-9]+')"
  repo="$(printf '%s' "$ref" | sed -E 's#https://github.com/([^/]+/[^/]+)/issues/[0-9]+#\1#')"
  gh issue view "$issue_number" --repo "$repo" --json number,title,url,body,comments
else
  fail "could not parse issue reference: $ref"
fi
