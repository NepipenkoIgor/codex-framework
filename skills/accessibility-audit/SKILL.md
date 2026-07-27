---
name: accessibility-audit
description: Audit a defined frontend sample against applicable WCAG 2.2 Level A or AA criteria using code, rendered-state, keyboard, and assistive-technology evidence. Use for a read-only accessibility findings report; do not use when remediation is the primary deliverable.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 1.5
  argument-hint: "page URL or component path, conformance target, sampled routes/templates/states, browsers and assistive technologies"
---

# Accessibility Audit

Audit `$ARGUMENTS` read-only. Findings and remediation guidance are allowed; repository or external-state changes are not.

For an existing repository, manifests, resolved lockfiles, runtime files, generated types, browser policy, and installed capabilities are authoritative. Before using any version-sensitive command or API, verify that exact selection against at least one applicable installed capability source such as generated types, configuration schema, CLI help, or matching official documentation; manifest script existence alone is not capability evidence. For greenfield analysis, resolve current stable/LTS releases from official sources at execution time, verify cross-stack compatibility, and once a project is generated treat its manifest and resolved lockfile as the authoritative stack record rather than the earlier lookup.

## Define the claim before testing

1. Record the requested conformance target, product/browser support policy, and exact sample: routes, templates, components, viewport/zoom, themes, locales, auth roles, states, input methods, and assistive technologies.
2. Inspect authoritative source, rendered DOM/styles, design primitives, existing accessibility checks, and user flows. Do not infer runtime semantics solely from JSX/templates.
3. Map applicable WCAG criteria to evidence methods. Automated rules find a subset; they do not prove conformance.
4. If a route, state, browser, assistive technology, or authenticated path cannot be exercised, mark it untested rather than extrapolating.
5. When the supplied repository contract requires focused tests, affected tests, type-check, or build evidence, derive exact commands from its manifest and require every applicable category before declaring the audit complete. If read-only scope or the environment prevents execution, report each category as not run and block the corresponding completion or conformance claim rather than making it optional.

## Evidence methods

- Prefer native HTML semantics and built-in behavior. Recommend ARIA only where native semantics cannot express the required contract, and verify that ARIA behavior is implemented.
- Use automated scanning for detectable names, roles, relationships, contrast, parsing, and common rules; manually validate each reported issue.
- Test keyboard order, visible focus, activation, escape/dismissal, skip/navigation, and focus restoration through representative workflows.
- Inspect accessible names/descriptions, headings, landmarks, status/error announcements, tables, forms, dialogs, pointer alternatives, reflow, zoom, motion, and color-independent meaning where applicable.
- Screen-reader or other assistive-technology claims require named tool/version, browser/platform, exact steps, and observed output. DOM inspection alone is not screen-reader evidence.
- Contrast must use rendered foreground/background and state, including overlays and opacity; source tokens alone may be insufficient.

## Evidence safety

- Runtime captures, accessible trees, recordings, console/network output, and test accounts may expose names, messages, emails, tokens, or other sensitive data. Use the least-privileged safe environment, minimize capture, redact PII/secrets, and do not retain artifacts without authorization.
- Do not enter destructive or consequential workflows merely to complete an audit. Use seeded/synthetic data and read-only paths where possible.

## Findings

For each reproducible finding report severity, criterion, exact page/component/state, affected users, steps, observed versus expected behavior, evidence method, and a remediation direction that favors native semantics. Distinguish confirmed defects, code-review risks requiring runtime confirmation, and coverage gaps.

Do not publish a fabricated "compliance percentage" or claim site-wide WCAG conformance from a sample. Summarize instead:

- sampled scope and environment;
- confirmed findings by severity and criterion;
- passed checks only within the tested sample;
- automated/manual/assistive-technology methods used;
- untested paths and residual risk;
- positive patterns supported by evidence.
