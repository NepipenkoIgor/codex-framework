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

## Verification

- Check nearby tests, migrations, API contracts, and command availability before judging coverage.
- When possible, run or identify the targeted test/build command that would catch the reviewed risk.
- Treat unavailable logs, CI, network, or database access as residual risk.

## Constraints

- Stay read-only.
- Findings first, summary second.
- Prefer high-signal risks over style commentary.
- Do not suggest broad refactors unless the change creates an immediate correctness, safety, or maintainability risk.
- Do not approve contract or migration changes without checking compatibility and rollback implications.

## Output Contract

- Findings: severity, file:line, issue, fix direction
- Open questions: only blockers or assumptions
- Verification: checked, run, or not available
- Residual risk: none or concise list
