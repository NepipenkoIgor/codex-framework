---
name: firebase-patterns
description: Implement Firebase-backed application behavior across Firestore, Authentication, Security Rules, Cloud Functions, Storage, indexes, and messaging. Use when Firebase product semantics determine the repository change; do not use for provider-neutral architecture, notification delivery alone, or diagnosis/review without implementation.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  argument-hint: "Firebase products, client/admin boundary, data paths, actors, runtime, deployment target"
---

# Firebase Implementation

Implement `$ARGUMENTS` against the repository's configured Firebase projects and installed SDK/CLI capabilities.

## Workflow

1. Read local instructions, manifests and lockfiles, `firebase.json`, project aliases, emulator configuration, rules/index files, runtime declarations, initialization code, and nearby tests. Resolve exact project IDs and aliases; never infer a production target from a default alias.
2. Generate stack context for the project. Preserve supported pins unless migration is explicit. Verify APIs against installed types, CLI help/config schema, and matching official Firebase documentation. For volatile SDK, Functions runtime, quota or deployment claims, record the exact installed/runtime capability with the applicable official Firebase release-notes or runtime-management source below.
3. Map every caller and trust boundary: mobile/web client, Admin SDK or server client, Cloud Function, REST/RPC caller, service account, Firebase project, tenant, collection/path, Storage bucket, and messaging audience.
4. Design Firestore documents and queries from measured access/write patterns, consistency needs, transaction limits, index requirements, contention, retention, and cost. Bounded fields and subcollections are decisions supported by the product contract, not remembered size/count thresholds.
5. Author mobile/web Security Rules deny-first for the exact operations and fields. Test overlapping matches, query compatibility, immutable fields, create/update/delete separately, cross-tenant access, and unauthenticated access. Remember that matching allows combine with logical OR and rules are not result filters.
6. Treat Admin SDK and server client access separately: they bypass Firestore Security Rules. Enforce authenticated principal, tenant/resource authorization, input validation, least-privilege IAM/service accounts, and audit evidence in trusted server code.
7. Make event-driven Functions retry-safe and idempotent with a durable operation/event key and transactional state transition. Set runtime, region, timeout, concurrency, instances, and retry behavior only from observed workload, dependency limits, cost policy, and currently supported platform options.
8. For Authentication, verify tokens and session freshness in trusted code; rotate/revoke sessions where the flow requires it. Treat custom claims as authorization hints with propagation/staleness behavior, not an instantly consistent database or sole authority for rapidly changing membership.
9. For FCM, Storage, Hosting, or other products, implement only the selected capability. Authorize every token/topic/object/route association, handle stale endpoints and retries, and evaluate client SDK, Admin SDK, Functions runtime, CLI/config, framework bundler, service-worker path, emulator and deployment runtime together before selecting the installed-line behavior.
10. Run emulator-backed focused tests and repository checks first. Before any deploy, inspect the exact diff/plan and target project, obtain the task's external-write authority, deploy only the bounded resource set, then verify deployed rules/functions/index state, allowed and denied caller journeys, duplicate-handling outcome, logs/metrics and the configured rollback signal. Do not treat a successful CLI exit as production proof.

## Stop conditions

Stop before mutation when the project/alias, actor authority, data ownership, migration/rollback plan, or safe emulator/test boundary is unresolved. A production deploy, destructive data migration, IAM change, secret rotation, or broad rules replacement requires explicit task scope and exact target confirmation.

## Counterexamples

- A rule that permits any authenticated user to read every user document is not a safe default.
- A narrow child rule cannot override a broader matching allow rule.
- Passing emulator rule tests does not prove Admin SDK authorization because server clients bypass those rules.
- A function incrementing a counter on a retried event without durable deduplication can double-apply state.
- A remembered SDK major, Node runtime, Functions generation, API shape, quota, document threshold, or framework adapter is not authority.
- Deploying all Firebase resources to “the current project” is unsafe when aliases or environments are ambiguous.

## Verification and output

Cover denied and allowed rule cases, query/rule compatibility, Admin IAM and tenant checks, duplicate/out-of-order events, transaction conflicts, index readiness, emulator isolation, auth revocation/staleness, and exact deployment rollback where affected. Report stack/project evidence, boundaries and model decisions, files changed, emulator/repository/deployment checks and results, and cost/security risks. Enumerate each authorized external mutation with its exact project/resource target separately, plus every withheld or unverified resource; do not collapse them into a generic deploy result.

## Official provenance

- Security Rules behavior: https://firebase.google.com/docs/rules/rules-behavior
- Firestore rules testing and Admin bypass boundary: https://firebase.google.com/docs/firestore/security/test-rules-emulator
- Functions runtime and deployment management: https://firebase.google.com/docs/functions/manage-functions
- Firebase JavaScript release notes: https://firebase.google.com/support/release-notes/js
