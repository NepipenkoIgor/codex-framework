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

## Workflow

Convert issue discussion into a small, testable contract. The spec should preserve the newest maintainer clarification, separate already-satisfied requirements from missing behavior, and make visual verification explicit.

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

## Constraints

- Do not overwrite an existing spec without reporting current status first.
- Do not drop later issue comments when they refine or override the issue body.
- Do not download or inline sensitive attachments into git-tracked files.
- Do not convert ambiguous discussion into requirements; mark it as a question.

## Verification

- Confirm issue title, issue number, comment count, attachment count, and generated spec path.
- Validate that every requirement row has an observable pass/fail condition.
- Mark visual rows with enough target information for `/verify`.

## Output Contract

- Status: done | partial | blocked
- Changed: `.codex/specs/{N}/spec.md`, downloaded refs, or none
- Requirements: count and unresolved questions
- Visual: yes | no
- Notes: attachment count, source limitations, or blockers
