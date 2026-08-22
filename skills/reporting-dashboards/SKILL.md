---
name: reporting-dashboards
description: Implement authorized reporting queries, dashboard APIs, consistent exports, scheduled reports, and live feeds. Use when repository changes to reporting or export behavior are requested; do not use for UI-only visualization or read-only performance diagnosis.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.1
  argument-hint: "metrics, subject/tenant scope, time semantics, export formats, consistency and load requirements"
---

# Reporting and Dashboards

## Workflow

1. Inspect metric definitions, source-of-truth tables/events, tenant/resource authorization, policy-driven capabilities, time zones/calendars, data freshness, warehouse/replica/materialized views, export delivery, queue/streaming primitives, manifests, and tests. Once the stack is known, explicitly check every applicable runtime engine range, dependency peer, compiler/framework, test-runner and deployment-runtime relationship; mark absent or unavailable dimensions rather than using a generic compatibility claim. Before disabling, restricting or mutating production reporting/export behavior, resolve explicit operational authority, exact environment/resource, owner and a tested rollback/re-enable procedure.
2. Define each metric's grain, filters, inclusion/exclusion, currency/unit, correction policy, time basis, freshness and reconciliation. Do not hide business semantics inside an aggregation query.
3. Authorize every dashboard, schedule, export, row and sensitive column from server-side subject/tenant/resource policy. Never trust client tenant IDs or prescribe fixed viewer/manager/admin roles; BI credentials and signed downloads need the same bounded scope.
4. Choose live query, summary table, materialized view, replica, warehouse, or stream from measured workload, product latency/freshness policy and measured capacity. Do not use fixed latency, row, interval, replica-lag, or page caps as universal rules.
5. For a multi-page/file export, establish one consistent database snapshot or versioned report manifest so pages cannot mix states. Bind it to requester, tenant, filters, columns, locale/timezone, source watermark, expiry, and audit record.
6. Stream with real backpressure: await drain/producer demand, bound buffers and concurrency, cancel database cursors and work on client disconnect/abort, and clean partial artifacts. Derive cleanup retry attempt and elapsed-time bounds from storage/provider behavior, artifact expiry and job deadline, then surface exhausted cleanup for operator reconciliation. Queue heavy reports according to measured resource risk, not format alone.
7. Define time windows with an IANA zone, calendar semantics and explicit half-open UTC boundaries. Test DST gaps/folds, leap/calendar boundaries, locale formatting, and source timestamps; a fixed offset is not a timezone.
8. Map every applicable repository and product review-checklist item to a traceable acceptance criterion and executable evidence. Completion remains blocked until each item is satisfied or marked inapplicable with task evidence, and until any stakeholder approval required by the repository/product contract is recorded; inspecting a checklist or noting that approval is unavailable is not a passed gate.

## Safe Exports

- CSV-quote delimiters, quotes, CR/LF and Unicode correctly. Neutralize spreadsheet formula injection for untrusted cells beginning with formula-trigger characters according to the consumer contract, while preserving a raw machine-readable format when required.
- Use a server-owned allowlist for columns and header labels. Prevent CR/LF or delimiter injection in headers and validate spreadsheet sheet names.
- Build `Content-Disposition` with a server-generated safe filename plus standards-compatible encoded filename parameter; never interpolate client input or allow path separators/control characters/header injection.
- Escape HTML in spreadsheet/PDF templates, bound external asset fetching, and prevent spreadsheet links/formulas from becoming executable content unless explicitly trusted.

## Live Feeds and Reconciliation

Authenticate connection establishment and reauthorize tenant/resource scope. Use sequence/version identifiers, heartbeat and reconnect from an authoritative snapshot; deduplicate and handle gaps/out-of-order messages. Apply admission control and per-subject/tenant resource budgets derived from capacity evidence. Disconnect immediately when authorization is revoked where supported.

## Verification and Output

Test cross-tenant and per-row/column access; CSV cells beginning with `=`, `+`, `-`, `@`, tab or CR; malicious header/filename; snapshot consistency while source rows change; DST gap/fold; large/slow consumer backpressure; disconnect/abort; duplicate/out-of-order live events; revoked access; queue retry and partial artifact cleanup. Measure representative query/load behavior and report the dataset and environment rather than universal thresholds.

Return metric contracts, authorization matrix, source/snapshot/watermark, time semantics, export sanitization, load/backpressure decisions, executed consistency/security/performance tests, and residual warehouse/BI/delivery risk.
