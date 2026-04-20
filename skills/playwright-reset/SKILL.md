---
name: playwright-reset
description: Kill the browser automation helper process (`playwright-mcp`), clean stale temp dirs, and report status. Use when browser automation is crashing or "Target page closed" errors won't stop.
metadata:
  version: 1.0
  user-invocable: true
  argument-hint: ""
---

# /playwright-reset — Fix browser automation

## What this does

One command to kill the `playwright-mcp` helper process and clean stale temp dirs. Replaces having to remember the exact pkill + find command.

## Orchestrator instructions

When user invokes `/playwright-reset`:

1. Tell the user to run this in the terminal (Codex should not run pkill blindly from a reusable workflow):

```
! pkill -f playwright-mcp; find /tmp -maxdepth 1 -name "playwright*" -type d -exec rm -rf {} + 2>/dev/null; echo "Playwright reset done"
```

2. After user confirms it ran → tell them:
   - "browser automation will reconnect on next use. If you were mid-verification, run `/verify` to resume."
   - "If the error was 'browser automation server disconnected' (not just stale context): restart the current Codex session after running the command."

3. Explain the two error types so user knows which applies:
   - **"Target page, context or browser has been closed"** → stale context handle, NOT fatal. The reset command fixes it. No restart needed — just retry the browser operation.
   - **"browser automation server disconnected"** → fatal. Reset + restart the current Codex session required.

## Output contract
Status: done
Changed: none
Notes: cleanup command shown above — user must run it manually
