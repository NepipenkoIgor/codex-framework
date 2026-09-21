---
name: error-tracking
description: Implement privacy-safe error capture, release/source-map correlation, grouping, sampling, alerting and ownership using the repository's installed provider SDK. Use when error-tracking repository changes are requested.
metadata:
  owner: codex-framework
  reviewed: "2026-09-21"
  version: 2.1
  argument-hint: "stack and installed SDK, environments/releases, privacy policy, expected error classes/volume, on-call ownership"
---

Implement error tracking for $ARGUMENTS.

Read instructions, manifests/lockfiles, installed SDK/provider configuration, app entry/error boundaries, release build/source maps or debug symbols, auth/logout, privacy/retention policy, observability and on-call routing. Verify SDK APIs and integrations from installed types/config or matching official docs; do not copy remembered Sentry APIs or upgrade incidentally. Before material SDK/configuration/code mutation, resolve exact targets, owner and write authority/permissions, configuration/code rollback and provider-event reconciliation. Derive any automated retry/wait attempts and elapsed time from provider/build evidence; otherwise leave them unresolved.

For provider reads, first prove authenticated connector or CLI identity plus exact organization/project/environment/time/filter scope and parseable completeness. Empty, truncated, mixed-warning or unsupported CLI output is inconclusive; use a same-scope authenticated API next. Open the provider Browser only for genuinely visual/UI-only evidence after that path is exhausted. Never substitute a different account, project or environment after authentication failure.

For authorized greenfield version selection, resolve stable frameworks and production LTS runtimes from exact official distribution/support sources, verify cross-stack compatibility, and generate the manifest plus lockfile. Once generated, those files become the continuing version and compatibility authority; future work reads their pins rather than re-resolving `latest`, and upgrades are separate migrations.

Define capture boundaries for unhandled and intentionally reported errors. Preserve original cause/stack while normalizing provider/noisy wrappers. Expected validation/authorization/network outcomes are not automatically exceptions.

Default to data minimization. Do not attach user email, IP, request bodies, tokens, cookies, order IDs/amounts, payment/customer data, query parameters or arbitrary object state unless each field has explicit support need, lawful basis, access/retention and redaction. Prefer opaque internal correlation IDs with controlled lookup. Verify scrubbing before events leave the process and in attachments, breadcrumbs, replay, source maps and logs.

Tags and fingerprints must be bounded. Never fingerprint or tag by tenant/user/request/order/URL/raw message. Group from stable error type, normalized stack and bounded component/operation; test both over-grouping and explosion. Sampling, replay, ignore rules, alerts and retention come from volume, cost, harm and support goals—not fixed rates or thresholds. Sampling changes truth: dashboards must expose captured versus estimated population and never imply unsampled events were observed.

Bind events to immutable release/artifact and environment; upload source maps/symbols through least-privilege CI and prevent public artifact exposure. Clear user scope on logout and isolate environments/tenants appropriately.

Verify representative handled/unhandled errors, redaction, logout, grouping/cardinality, sampling accounting, release symbolication, alert ownership/noise and provider failure. Report data fields/retention, installed capability evidence, grouping/sampling decisions, changes, checks and unverified provider-side configuration.
