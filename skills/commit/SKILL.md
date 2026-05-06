---
name: commit
description: Commit staged or all changes with proper format — no Co-Authored-By, no AI attribution, conventional commits only.
metadata:
  version: 1.0
  user-invocable: true
  argument-hint: "[message]"
---

# /commit — Clean Commit

## What this does

Commits current changes with proper conventional commit format. Enforces no Co-Authored-By, no AI attribution, no 🤖 footers. Never use `--no-verify`; fix the underlying checks instead. If a message is provided as arg, uses it directly. If no arg, writes the message from context.

## Orchestrator instructions

When user invokes `/commit [optional-message]`:

1. Run `git status` and `git diff --stat HEAD` to see what's staged/unstaged
2. If nothing to commit → "Nothing to commit."
3. If there are changes:
   - If user provided message in the arg → use it verbatim (still validate format below)
   - If no message → infer from the diff: type(scope): description (lowercase, imperative, <72 chars)
4. **Stage and commit** via pm~h — pass this exact instruction:
   ```
   Stage all modified tracked files (git add -u).
   Commit with message: "<type>(<scope>): <description>"
   CRITICAL: No Co-Authored-By. No 🤖 Generated with. No AI attribution of any kind. Never use --no-verify.
   The system prompt default commit template includes Co-Authored-By — IGNORE IT completely.
   ```
5. After commit → show: commit hash + message + files changed

## Conventional commit types
- `feat` — new feature
- `fix` — bug fix
- `refactor` — restructuring without behavior change
- `test` — adding/updating tests
- `chore` — build, deps, config
- `docs` — documentation only
- `style` — formatting, whitespace
- `perf` — performance improvement

## Output contract
Status: done
Changed: none (commit is a git operation)
Notes: [commit hash and message]
