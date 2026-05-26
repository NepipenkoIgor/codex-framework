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

requirement_entries = []
seen_requirements = set()
requirement_keywords = re.compile(
    r"\b(acceptance|expected|required|requirement|should|must|need(?:s|ed)? to|please|make sure)\b"
    r"|должн|нужно|надо|треб|ожида|сдела|добав|исправ|убер",
    re.IGNORECASE,
)
requirement_headings = {
    "requirements",
    "acceptance",
    "acceptance criteria",
    "criteria",
    "scope",
    "todo",
    "tasks",
    "done when",
    "требования",
    "критерии приемки",
    "что сделать",
}

def normalize_requirement(text: str) -> str:
    text = re.sub(r"^\[[ xX]\]\s+", "", text.strip())
    text = re.sub(r"\s+", " ", text)
    return text.strip(" -")

def add_requirement(text: str, location: str) -> None:
    req = normalize_requirement(text)
    if len(req) < 3:
        return
    key = req.casefold()
    if key in seen_requirements:
        return
    seen_requirements.add(key)
    requirement_entries.append({"text": req, "location": location})

def extract_requirements(label: str, text: str) -> None:
    in_requirement_block = False
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped:
            continue

        heading = re.sub(r"^#+\s*", "", stripped).strip().lower()
        if heading in requirement_headings:
            in_requirement_block = True
            continue
        if stripped.startswith("#"):
            in_requirement_block = False
            continue

        checklist = re.match(r"^[-*]\s+\[[ xX]\]\s+(.+)$", stripped)
        bullet = re.match(r"^([-*]|\d+\.)\s+(.+)$", stripped)
        if checklist:
            add_requirement(checklist.group(1), label)
        elif bullet:
            add_requirement(bullet.group(2), label)
        elif in_requirement_block and len(stripped) <= 220:
            add_requirement(stripped, label)
        elif label.startswith("Comment") and len(stripped) <= 220 and requirement_keywords.search(stripped):
            add_requirement(stripped, label)

extract_requirements("Issue body", body)
for idx, text in enumerate(comment_texts, start=1):
    extract_requirements(f"Comment {idx}", text)

if not requirement_entries:
    summary = body.split("\n\n")[0].replace("\n", " ").strip()
    if summary:
        add_requirement(summary[:160], "Issue body")
    else:
        add_requirement(f"Implement issue #{data.get('number')} based on title and discussion", "Issue")

spec_lines = []
spec_lines.append(f"# Spec #{data.get('number')} - {title}")
if url:
    spec_lines.append(f"Source: {url}")
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
for idx, entry in enumerate(requirement_entries, start=1):
    escaped = entry["text"].replace("|", "\\|")
    escaped_location = entry["location"].replace("|", "\\|")
    spec_lines.append(f"| {idx} | {escaped} | {escaped_location} | ☐ |")
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
