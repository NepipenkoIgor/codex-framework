---
name: backend-debug
description: Diagnose and fix backend bugs — API failures, runtime exceptions, broken jobs, bad queries, async issues, and integration failures
metadata:
  version: 3.0
  argument-hint: "bug description, stack, failing endpoint/job, logs or reproduction details"
---

Debug $ARGUMENTS.

## Tool Integration

- Use logs, failing requests, tests, and reproduction steps as primary evidence.
- Use diagnostics and code navigation tools after you have identified the failing path.
- Use browser reproduction when the backend bug manifests through a UI flow.

## Debugging Principles

- Gather evidence before changing code.
- Trace the failing path end to end.
- Prefer the smallest correct fix over cleanup work.
- Verify the changed contract or failure mode after fixing.

## Diagnosis Workflow

1. Identify the exact failing behavior or error.
2. Reproduce it using logs, tests, HTTP requests, or the UI flow.
3. Trace request validation, orchestration, persistence, and integrations.
4. Look for boundary mismatches, hidden side effects, race conditions, retries, timeout issues, or query defects.
5. Fix the actual cause, not just the symptom.

## Risk Areas

- validation drift
- async orchestration bugs
- transaction boundaries
- retry or idempotency defects
- paging and filtering mistakes
- error mapping and status code regressions

## Output Requirements

- Describe the root cause succinctly.
- Apply the smallest safe fix.
- State what evidence was used and what was verified afterward.
