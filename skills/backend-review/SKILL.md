---
name: backend-review
description: Review backend code for correctness, security, performance, reliability, and contract integrity
metadata:
  version: 2.0
  argument-hint: "PR/diff/module, stack, review scope"
---

Review $ARGUMENTS.

## Review Priorities

- correctness and regressions
- security and validation
- performance and query shape
- database consistency, migrations, transactions, and index impact
- reliability and async behavior
- contract integrity
- hardcoded secrets, environment constants, tenant assumptions, or layer bypasses
- missing tests

## Method

1. Read the actual diff or target files first.
2. Focus on changed behavior and boundary contracts.
3. Report findings with file references and concrete fix direction.
4. If no findings are discovered, say so and note any unverified areas.

## Constraints

- Stay read-only.
- Findings first, summary second.
- Prefer high-signal risks over style commentary.
