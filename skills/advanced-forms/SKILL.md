---
name: advanced-forms
description: Implement complex forms with schema-driven state, conditional fields, drafts, uploads, accessible errors, and safe server submission. Use when multi-step or high-consequence form behavior is primary; do not use for API validation architecture alone.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  argument-hint: "form workflow, data sensitivity, server contract, draft policy, upload types, mutation consequences"
---

# Advanced Forms

Generate repository stack context with `python3 scripts/framework-stack-context.py project <path>`, then inspect the framework, TypeScript/compiler, form and schema libraries/adapters, runtime versions, server validation and field/form error contract, authorization model, storage policy, design system, and tests as one compatibility unit before choosing APIs. Existing pins are authority; verify matching official documentation and installed declarations, and treat an upgrade as separate scope. For greenfield work use `python3 scripts/framework-stack-context.py latest <technologies...>`, then verify generated manifests, resolved lockfiles, installed types, and official documentation.

This skill owns the form workflow and its direct server integration. Organization-wide validation architecture and generic upload/storage platform capabilities remain with their dedicated owners unless the request explicitly expands scope.

## Invariants

- The client improves feedback but is never the authorization or integrity boundary. The server revalidates canonical input, normalizes deliberately, authorizes the actor against the target, derives protected fields, and makes consequential submission idempotent.
- Do not store sensitive, regulated, credential, payment, health, identity, or tenant-confidential drafts in generic Web Storage. Define an approved server draft or protected device-storage design with encryption/threat model, partitioning, retention, revocation, logout purge, and cross-tab behavior.
- Fail-open submission is allowed only when the business rule explicitly permits accepting data the client could not validate and the server remains authoritative. Financial, permission, compliance, destructive, and irreversible flows fail closed.
- Hidden, disabled, stale-step, and client-computed fields are untrusted input. Conditional schemas must strip or reject data that is no longer applicable.
- File extension, MIME, image dimensions, and browser previews are hints. The server enforces size/type, scans or sandboxes according to threat model, generates storage names, prevents traversal/overwrite, isolates untrusted content, and controls download disposition.

## Workflow

1. Map steps, state transitions, canonical schema, server errors, permissions, side effects, retry/idempotency semantics, accessibility requirements, sensitive fields, draft retention, uploads, and abandonment.
2. Keep one typed form state and an explicit transformation to the API payload. Model conditional branches and cross-field rules in the schema; avoid duplicated component-level validation.
3. Choose validation timing by cost and consequence. Preserve user input across recoverable errors; focus and summarize errors accessibly without moving focus on every keystroke.
4. Make async validation cancellable and race-safe. Derive any debounce from measured interaction/provider behavior and product policy, not a reusable constant. A successful availability check is not a reservation; the server checks again transactionally on submit.
5. Autosave only to an approved product/data-policy draft boundary. Debounce is a UX optimization, not correctness: version drafts, reject/merge stale writes, expose saved/pending/error state, and prevent another user or tenant from reading them. Prove logout/account-switch purge removes the draft from every store that the former identity could access.
6. Upload through an authorized intent tied to actor, tenant, object, constraints, and expiry. Finalize only after the server verifies the stored object; clean abandoned objects with a bounded policy.
7. On submit, disable accidental duplicates while preserving an operation identity across ambiguous retries. Handle field, form, authorization, conflict, rate-limit, and unknown-outcome responses distinctly.

## Verification

- A passing consequential-form verification set must bypass client-side validation, hidden-step and workflow controls and prove the authoritative server rejects the invalid or unauthorized payload; ordinary happy-path server tests are insufficient.
- Keyboard and screen-reader navigation, error summary/focus, conditional add/remove, step resume, localization, autofill, back/refresh, and reduced connectivity.
- Client bypass, overposting, tenant/object substitution, concurrent submit, timeout after commit, duplicate retry, conflict, and partial side effects. Explicitly revoke or change authorization after draft/upload intent creation but before final submission and prove the server rejects stale authority.
- Draft cross-tab race, stale version, account switch/logout, retention expiry, sensitive-field exclusion, unavailable storage, and server-draft authorization.
- Upload renamed/polyglot/malformed/oversized content, metadata stripping where required, scan failure, direct-object substitution, abandoned upload, and safe serving.
- Repository tests plus server integration evidence and caller-visible persisted outcome; do not report UI success as proof of the mutation.

## Output Contract

- Form state/schema and server mutation contract
- Draft sensitivity, retention, concurrency, and purge decisions
- Upload trust boundary and lifecycle
- Accessibility and failure behavior
- Verification evidence and residual external-storage/scanner risk

Official security references: [OWASP Input Validation](https://cheatsheetseries.owasp.org/cheatsheets/Input_Validation_Cheat_Sheet.html), [OWASP File Upload](https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html), and [OWASP HTML5 Security](https://cheatsheetseries.owasp.org/cheatsheets/HTML5_Security_Cheat_Sheet.html).
