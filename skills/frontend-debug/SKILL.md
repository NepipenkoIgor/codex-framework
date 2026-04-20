---
name: frontend-debug
description: Diagnose and fix frontend bugs — rendering errors, broken state, JS exceptions, CSS layout issues, and network failures
metadata:
  version: 3.0
  argument-hint: "bug description, framework (React/Vue/Angular), reproduction steps, browser/env affected"
---

Debug $ARGUMENTS.

## Tool Integration

- Start with browser reproduction when a local URL or runtime path is available.
- Use diagnostics, code navigation, and structural search after you observe the symptom.

## Debugging Principles

- Diagnose the root cause before changing code.
- Distinguish symptoms from causes.
- Prefer the smallest safe fix.
- Verify state ownership, reactive triggers, side effects, and async behavior before broad changes.

## Bug Diagnosis Approach

1. Identify the symptom precisely and restate expected behavior.
2. Reproduce it in the browser when possible.
3. Trace state ownership, data flow, event handlers, effects, and async boundaries.
4. Check for stale state, duplicated state, race conditions, hydration issues, or invalid validation assumptions.
5. Apply the smallest safe fix.

## Framework Guidance

- React / Next.js: inspect dependency arrays, stale closures, unstable references, and server/client boundaries.
- Angular: inspect signal loops, effect misuse, and change-detection churn.
- Vue / Nuxt: inspect refs, watchers, computed chains, and reactive object boundaries.
- Svelte: inspect derived state and effect ordering.

## Remediation Workflow

1. Mitigate immediate user impact if needed.
2. Fix the root cause.
3. Add or update a regression check when justified.
4. Verify the changed flow again.

## Output Requirements

- Explain the likely root cause.
- Make the smallest correct fix.
- State what was verified and what remains unverified.
