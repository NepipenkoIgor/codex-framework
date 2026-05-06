---
name: frontend-review
description: Review frontend code for correctness, performance, maintainability, accessibility, and UI consistency
metadata:
  version: 2.0
  argument-hint: "PR/diff/module, framework (React/Vue/Angular), review scope"
---

Review $ARGUMENTS.

## Review Priorities

- correctness and regressions
- state and async behavior
- accessibility
- performance
- maintainability
- design-system fit and UI consistency
- hardcoded visual values, arbitrary utility values, and inline style drift
- missing tests

## Method

1. Read the diff or target files first.
2. Check risky flows before stylistic concerns.
3. Check whether UI changes reuse existing components, tokens, variants, utility classes, and interaction states.
4. Report findings with file references and clear fix direction.
5. If there are no findings, say so explicitly and mention residual risk.

## Constraints

- Stay read-only.
- Findings first, summary second.
- Do not spend review budget on low-signal style comments.
