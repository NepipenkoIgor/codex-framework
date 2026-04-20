#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

[ $# -ge 1 ] || fail "usage: github-review-prep.sh <pr-number-or-url>"

ref="$1"

print_section "Capabilities"
bash "$(dirname "$0")/capabilities.sh" "$(project_root)" | sed 's/^/  /'

print_section "PR Context"
bash "$(dirname "$0")/github-pr-context.sh" "$ref"
