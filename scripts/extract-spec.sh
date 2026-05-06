#!/bin/bash
set -euo pipefail

. "$(dirname "$0")/lib.sh"

[ $# -ge 1 ] || fail "usage: extract-spec.sh <issue-number-or-url> [--refresh]"

issue_ref="$1"
mode="${2:-}"
ROOT="$(project_root)"
ensure_project_bootstrap "$ROOT" >/dev/null 2>&1 || fail "failed to bootstrap project state"
ensure_spec_root

parse_issue_number() {
  local ref="$1"
  if printf '%s' "$ref" | grep -Eq '^[0-9]+$'; then
    printf '%s\n' "$ref"
    return 0
  fi
  if printf '%s' "$ref" | grep -Eq '/issues/[0-9]+'; then
    printf '%s\n' "$ref" | grep -oE '/issues/[0-9]+' | grep -oE '[0-9]+'
    return 0
  fi
  return 1
}

parse_issue_repo() {
  local ref="$1"
  if printf '%s' "$ref" | grep -Eq '^https://github\.com/[^/]+/[^/]+/issues/[0-9]+'; then
    printf '%s\n' "$ref" | sed -E 's#https://github.com/([^/]+/[^/]+)/issues/[0-9]+#\1#'
    return 0
  fi
  return 1
}

issue_number="$(parse_issue_number "$issue_ref" || true)"
[ -n "$issue_number" ] || fail "could not parse issue number from: $issue_ref"
issue_repo="$(parse_issue_repo "$issue_ref" || true)"

spec_dir="$(spec_root)/$issue_number"
spec_file="$spec_dir/spec.md"
raw_file="$spec_dir/issue.json"
mkdir -p "$spec_dir"

if [ -f "$spec_file" ] && [ "$mode" != "--refresh" ]; then
  printf '%s\n' "$spec_file"
  exit 0
fi

has_command gh || fail "gh CLI is required for issue-based work"

gh_args=(issue view "$issue_number" --json number,title,url,body,comments)
if [ -n "$issue_repo" ]; then
  gh_args+=(--repo "$issue_repo")
fi

if ! gh "${gh_args[@]}" > "$raw_file"; then
  fail "failed to fetch issue #$issue_number via gh"
fi

python3 - "$raw_file" "$spec_file" <<'PY'
import json
import pathlib
import re
import sys

raw_path = pathlib.Path(sys.argv[1])
spec_path = pathlib.Path(sys.argv[2])
data = json.loads(raw_path.read_text(encoding="utf-8"))

title = data.get("title", f"Issue {data.get('number', '')}").strip()
url = data.get("url", "").strip()
body = (data.get("body") or "").strip()
comments = data.get("comments") or []

def clean(text: str) -> str:
    return re.sub(r"\r\n?", "\n", text).strip()

body = clean(body)
comment_texts = [clean((c or {}).get("body") or "") for c in comments]
all_text = "\n".join([body] + comment_texts)

attachment_urls = []
for match in re.finditer(r"https?://[^\s)>\"]+", all_text):
    url_match = match.group(0)
    if any(key in url_match for key in ("user-attachments", "user-images", ".png", ".jpg", ".jpeg", ".gif", ".webp", ".pdf", ".zip", ".csv", ".md", ".txt")):
        attachment_urls.append(url_match)

seen = set()
deduped_urls = []
for item in attachment_urls:
    if item not in seen:
        seen.add(item)
        deduped_urls.append(item)

lines = []
for line in body.splitlines():
    stripped = line.strip()
    if not stripped:
        continue
    if stripped.startswith(("- ", "* ", "1. ", "2. ", "3. ", "4. ", "5. ")):
        lines.append(re.sub(r"^([-*]|\d+\.)\s+", "", stripped))

requirements = []
for item in lines:
    if item not in requirements:
        requirements.append(item)

if not requirements:
    summary = body.split("\n\n")[0].replace("\n", " ").strip()
    if summary:
      requirements.append(summary[:160])
    else:
      requirements.append(f"Implement issue #{data.get('number')} based on title and discussion")

spec_lines = []
spec_lines.append(f"# Spec #{data.get('number')} - {title}")
if url:
    spec_lines.append(f"Source: {url}")
spec_lines.append(f"Last synced: {pathlib.datetime.datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ') if False else ''}")
spec_lines.pop()  # placeholder removed; set below for compatibility
from datetime import datetime, timezone
spec_lines.append(f"Last synced: {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}")
spec_lines.append(f"Visual: {'yes' if deduped_urls else 'no'}")
spec_lines.append("")
spec_lines.append("## Summary")
spec_lines.append("")
spec_lines.append(title)
if body:
    spec_lines.append("")
    spec_lines.append(body[:1200].strip())
spec_lines.append("")
spec_lines.append("## Requirements")
spec_lines.append("")
spec_lines.append("| # | Requirement | Location | Status |")
spec_lines.append("|---|---|---|---|")
for idx, req in enumerate(requirements, start=1):
    escaped = req.replace("|", "\\|")
    spec_lines.append(f"| {idx} | {escaped} | — | ☐ |")
spec_lines.append("")
spec_lines.append("## Comments")
spec_lines.append("")
if comment_texts:
    for idx, text in enumerate(comment_texts[:10], start=1):
        excerpt = text[:400].strip() or "(empty)"
        spec_lines.append(f"### Comment {idx}")
        spec_lines.append("")
        spec_lines.append(excerpt)
        spec_lines.append("")
else:
    spec_lines.append("No comments.")
    spec_lines.append("")
spec_lines.append("## Attachments")
spec_lines.append("")
if deduped_urls:
    for url_item in deduped_urls:
        spec_lines.append(f"- {url_item}")
else:
    spec_lines.append("None detected.")
    spec_lines.append("")

spec_path.write_text("\n".join(spec_lines).rstrip() + "\n", encoding="utf-8")
PY

printf '%s\n' "$spec_file"
