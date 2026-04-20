---
name: spec
description: Extract a working spec from a GitHub issue and store it under the Codex framework spec path
metadata:
  version: 2.0
  user-invocable: true
  argument-hint: "<issue-number-or-url>"
---

# /spec — Extract Issue Spec

## What this does

Extracts a structured spec from a GitHub issue, stores supporting attachments, and prepares the work for execution.

## Orchestrator Instructions

When user invokes `/spec [arg]`:

1. Parse the issue reference:
   - number -> use directly
   - GitHub URL -> extract the issue number
   - no arg -> infer from branch name if possible

2. Check whether `.codex/specs/{N}/spec.md` already exists:
   - if it exists, report current status and ask whether to re-extract
   - if it does not exist, continue

3. Extract the issue:
   - read the issue body and comments
   - collect useful attachment URLs
   - download supporting files into `.codex/specs/{N}/`
   - inspect images or attachments when they contain requirements

4. Write `.codex/specs/{N}/spec.md` with:
   - title
   - issue summary
   - `Visual: yes|no`
   - a requirements table
   - attachment notes when relevant

5. After extraction, read the spec and present the next execution plan.

## Output Contract

Status: done | partial | blocked
Changed: [.codex/specs/{N}/spec.md, .codex/specs/{N}/ref-*]
Notes: [attachment count and requirement count]
