---
name: datagrid-patterns
description: Implement large interactive tables and grids with server query contracts, selection, editing, batch actions, export safety, concurrency, and accessible semantics. Use when grid interaction and data semantics are primary; do not use for general dashboard reporting.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.3
  argument-hint: "dataset, query/snapshot semantics, actions, authorization, accessibility, export requirements"
---

# Datagrid Patterns

Generate stack context with `python3 scripts/framework-stack-context.py project <path>`, then inspect the framework adapter, installed grid/table core, API contract, row identity/versioning, authorization rules, dataset scale, export consumers/formats, browser targets, generated DOM and installed test harness as one compatibility unit. For greenfield work resolve the selected stack with `python3 scripts/framework-stack-context.py latest <technologies...>`. Verify version-specific APIs against installed types, observed DOM and matching official docs; keep a capability fallback and treat grid-package migration as separate scope.

## Choose Semantics First

- Use a native HTML table for read-oriented tabular data and ordinary links/buttons. Do not add `role="grid"` merely for styling.
- Use the ARIA grid pattern only for a composite application widget with deliberate cell/row navigation, a single managed tab stop, focus persistence, selection semantics, and tested keyboard behavior. Virtualization must preserve logical row/column metadata and announcements.
- Define stable row identity separately from display position. Sorting, filtering, pagination, selection, and edits operate on IDs and row versions, never indexes.

## Server Contract

Choose native-table versus composite ARIA-grid semantics before selecting rendering or interaction APIs, then define the following server contracts. Server query, snapshot, authorization and mutation semantics remain independent of the selected grid rendering library.

1. Specify allowed sort/filter fields, null/collation/time-zone semantics, deterministic tie-breakers, pagination/cursor behavior, total-count meaning, and query limits.
2. Define whether a multi-page selection means explicit IDs, current-query membership, or a frozen dataset snapshot. For query-wide actions/export, persist a normalized query plus an authoritative snapshot/version/token; do not reinterpret it against a changed dataset silently.
3. Reauthorize every row and action server-side. A selected row set from the browser is not permission evidence. Destructive actions also compare the authoritative row version or equivalent concurrency token captured by the operation; stale rows conflict rather than being silently deleted. Return per-row accepted/rejected/conflict outcomes without leaking inaccessible row existence.
4. Protect inline edits with row versions or another concurrency contract. Preserve user input on conflict and offer an explicit refresh/merge/retry path.
5. Batch actions need operation identity, bounded chunking, cancellation semantics, progress based on durable outcomes, and a partial-failure model. Bind the exact tenant to the frozen selection and require consequence-appropriate destructive confirmation before execution; confirmation never replaces server authorization. Avoid presenting an ambiguous timeout as total failure or retrying the whole batch blindly.

## Export Safety

- Export from the authorized server-side dataset/snapshot, not whatever rows happen to be rendered.
- Treat spreadsheet formulas as executable content. For CSV/TSV intended for spreadsheet software, neutralize cells whose interpreted value can begin with formula/control syntax according to the chosen consumer and documented policy; quoting alone is not a universal defense. Test round trips in supported consumers.
- Apply field-level authorization, redaction, locale/encoding/newline rules, auditability, size limits, and asynchronous delivery where required. Prevent download URLs from becoming cross-tenant bearer leaks.

## Verification

- Stable sort and pagination under inserts/deletes; filter normalization; empty/large datasets; snapshot expiry; count semantics.
- Selection across pages and filters; permission and row-version changes; mixed authorized/unauthorized rows; partial batch failure; cancel/retry; timeout after commit; concurrent edits. Prove persisted per-row outcomes, snapshot accounting, protected audit evidence and caller-visible reconciliation for destructive batches.
- Native table and grid variants with keyboard, screen reader, focus after virtualized row removal, sticky regions, zoom, and responsive alternatives.
- CSV formula/control payloads, separators, quotes, Unicode, newlines, redacted fields, large export, and supported spreadsheet consumers.
- Focused unit/integration/browser tests and persisted server outcomes. Report library/browser limitations separately.

## Output Contract

- Query, identity, snapshot, selection, edit, and batch contracts
- Authorization and export threat model
- Chosen native-table or ARIA-grid semantics
- Tests and observable results
- Residual scale, consumer, and assistive-technology risks

Official foundations: [WAI-ARIA APG Grid Pattern](https://www.w3.org/WAI/ARIA/apg/patterns/grid/) and [OWASP CSV Injection](https://owasp.org/www-community/attacks/CSV_Injection).
