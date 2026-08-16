---
name: e2e-test
description: Implement browser end-to-end tests for critical user-visible web flows using the repository's installed runner, authentication, data, and server lifecycle conventions. Use when executable browser coverage is requested.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.0
  argument-hint: "critical flows, browsers/viewports, auth roles, test environment/data APIs, CI runner"
---

Implement end-to-end tests for $ARGUMENTS.

## Preserve the harness

Read instructions, manifests/lockfiles, existing E2E configuration/helpers, app routes and accessibility, authentication/session model, data setup APIs, environment ownership, CI/sharding, server commands and readiness endpoints. Start or attach to the repository-native server early and inspect the critical route in the visible in-app Browser before and after test implementation. Use the installed runner and repository scripts; do not impose Playwright, fixed browser projects, Node version, retries, workers, commands, timeouts or framework recipes from memory.

Verify runner/framework APIs using installed types/CLI/config schema or matching official docs. For greenfield work, use `scripts/framework-stack-context.py`. Avoid stale framework-specific APIs, including remembered Angular stabilization or zoneless names.

## Isolation and credentials

- Resolve an approved non-production target. Never run against production or shared mutable data without explicit authority and isolation.
- Provision least-privilege test identities through approved fixtures or secret storage. Do not commit credentials or share one mutable admin account across workers.
- Reuse authenticated storage state only when it is isolated by role/tenant/worker, contains no committed secrets, is refreshed safely, and cannot leak between projects. Validate expiry, logout/revocation and permission changes.
- Allocate run/worker-owned users, tenants and records. Register ownership, create transactionally where possible, and clean only exact owned data. Avoid timestamp-only uniqueness and broad teardown.

## Reliable behavior tests

Test user-observable outcomes using accessible roles/names and stable contract identifiers. Wait for explicit UI, URL, response, event or readiness conditions; avoid sleeps and `networkidle` as a universal readiness signal. Server readiness must prove the app and required dependencies are usable, not merely that a port is open.

Choose retries and time budgets from measured environment behavior. Retries may characterize flakes and capture trace/video/logs but must not hide them. Preserve first-failure evidence and fix shared state, ambiguous locators, race conditions or readiness defects.

Use controlled fakes for error/latency cases and approved isolated real services for integration behavior. Never call production providers, send real messages/payments, or mutate external accounts. Cover authorization denial, role/tenant separation, loading/error/empty/offline states and consequential action idempotency where affected.

## Verification and output

Run focused tests, then the repository's affected browser/shard matrix and relevant type/lint/build checks. Prove parallel isolation, auth-state separation, setup/cleanup recovery and task-owned server/process/tab cleanup. Headless execution proves regression automation but does not replace the visible in-app Browser acceptance loop; retain screenshots only when they prove a visual result.

Report flows, environments/browsers actually run, credential/data isolation, readiness and cleanup model, commands/results/artifacts, flakes, and untested provider or production boundaries. Do not claim completion from configuration or a retried green run alone.
