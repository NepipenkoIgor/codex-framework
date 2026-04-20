#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

[ $# -ge 1 ] || fail "usage: github-pr-context.sh <pr-number-or-url>"

ref="$1"
repo=""
number=""

if ! has_command gh; then
  fail "gh CLI is required"
fi

if ! gh auth status >/dev/null 2>&1; then
  fail "gh auth is required"
fi

if printf '%s' "$ref" | grep -Eq '^[0-9]+$'; then
  number="$ref"
elif printf '%s' "$ref" | grep -Eq '^#[0-9]+$'; then
  number="${ref#\#}"
elif printf '%s' "$ref" | grep -Eq 'github\.com/.*/pull/[0-9]+'; then
  number="$(printf '%s' "$ref" | grep -oE '/pull/[0-9]+' | grep -oE '[0-9]+')"
  repo="$(printf '%s' "$ref" | sed -E 's#https://github.com/([^/]+/[^/]+)/pull/[0-9]+#\1#')"
else
  fail "could not parse PR reference: $ref"
fi

print_section "PR"
if [ -n "$repo" ]; then
  gh pr view "$number" --repo "$repo" --json number,title,url,baseRefName,headRefName,headRefOid,author,reviewDecision
  print_section "Files"
  gh pr diff "$number" --repo "$repo" --name-only
else
  gh pr view "$number" --json number,title,url,baseRefName,headRefName,headRefOid,author,reviewDecision
  print_section "Files"
  gh pr diff "$number" --name-only
fi
