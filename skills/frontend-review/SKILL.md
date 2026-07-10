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
- strict CSP compatibility: no new avoidable `style` attributes, inline `<style>`, inline event handlers, or reliance on `'unsafe-inline'`
- missing tests

## Method

1. Read the diff or target files first.
2. Check risky flows before stylistic concerns.
3. Check whether UI changes reuse existing components, tokens, variants, utility classes, and interaction states.
4. Report findings with file references and clear fix direction.
5. If there are no findings, say so explicitly and mention residual risk.

## Verification

- Inspect the rendered states implied by the diff: loading, error, empty, disabled, hover/focus, mobile, and desktop.
- Prefer local browser, story, visual regression, or component tests when available.
- If browser automation or screenshots are unavailable, say the review is code-only.

## Constraints

- Stay read-only.
- Findings first, summary second.
- Do not spend review budget on low-signal style comments.
- Do not approve hardcoded visual values when repo tokens or variants exist.
- Treat avoidable inline styles as a finding when the app has or should have strict CSP headers.
- Do not treat accessibility, responsive behavior, or state coverage as optional when the UI changed.

## Output Contract

- Findings: severity, file:line, issue, fix direction
- Open questions: only blockers or assumptions
- Verification: browser/test/code-only evidence
- Residual risk: none or concise list
