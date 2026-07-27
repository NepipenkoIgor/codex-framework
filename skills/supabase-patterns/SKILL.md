---
name: supabase-patterns
description: Implement Supabase database, RLS, Auth/SSR, Edge Function, Realtime, Storage, migration, and generated-type changes. Use for requested repository implementation; do not use for diagnosis-only, generic PostgreSQL tuning, or Firebase work.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  argument-hint: "feature, subject/tenant/object authority, installed Supabase packages, target environment"
---

# Supabase Patterns

## Discovery and Version Context

Read repository instructions, `supabase/config.toml`, migrations/declarative schemas, generated types, exposed schemas, grants, RLS policies, functions/triggers, Auth/SSR code, Storage policies, environment linkage, manifests and lockfiles. Run `scripts/framework-stack-context.py project <path>` and use the detected `supabase-js` and `supabase-ssr` pins, installed types, CLI help, and matching official docs. Resolve current stable packages only for greenfield work; do not silently upgrade.

## Authorization

- Derive the authenticated subject from a verified request, never from body/query/path claims. Resolve tenant membership, role/capability, target row, and object/bucket ownership independently for each operation.
- On server auth decisions, use the strongest installed supported capability for the requirement: `getUser()` checks with the Auth server; `getClaims()` can verify JWT signature/expiry locally when its limitations are acceptable. Do not use `getSession()` as authorization evidence, and do not assume `getClaims()` proves server-side logout/revocation.
- A user-called Edge Function must authenticate the caller and normally use a user-scoped client so RLS applies. Never expose an unauthenticated handler that uses a service/secret-role client for sensitive reads or writes. Public webhooks must verify the provider signature before privileged work; service-to-service callers need an explicit secret/auth contract.
- Service/secret-role credentials stay server-side, bypass RLS, and require explicit subject/tenant/object authorization plus least-privilege operation scope. CORS is not authentication.

## Database and RLS

- RLS is mandatory for tables and storage metadata reachable through an exposed Data API schema, but it does not replace grants, schema exposure review, column privileges, function grants, or server authorization. Revoke unnecessary default privileges.
- Write separate `USING` and `WITH CHECK` policies per operation as needed. An `UPDATE` also needs a compatible `SELECT` policy; prove both row visibility and the post-update ownership constraint. Test anonymous, authenticated non-member, wrong tenant, wrong object owner, removed member, and privileged service paths. User-editable metadata is not an authorization source, and authorization claims cached in a JWT may remain stale until refresh.
- Views may use creator privileges; use supported security-invoker behavior or revoke/move them outside exposed schemas. Review every materialized view and RPC exposure separately.
- Put `SECURITY DEFINER` helpers in a non-exposed schema, schema-qualify every referenced object, set a safe fixed `search_path` (commonly empty), use a narrowly privileged non-superuser owner where feasible, revoke execute from `public`/broad roles, grant only intended callers, and test direct invocation. Do not create such helpers merely as a performance shortcut.

## Migration Workflow

1. Resolve exact local/linked project before any command; remote mutation requires explicit authorization.
2. Preserve applied migrations. Create a new migration or follow the repository's declarative-schema workflow; never edit history already applied to a shared environment.
3. Review generated SQL, locks, destructive statements, RLS/grants, function owner/search path, backfill bounds, mixed-version compatibility, rollback/forward-fix, and generated types.
4. Rebuild locally from migrations and seed; test policies using independent subjects/tenants. Preview linked changes with the installed CLI capability before one coordinated deploy.
5. Treat migration-history repair as exceptional evidence-based reconciliation; it changes history metadata and does not apply/revert SQL. Never reset a non-throwaway linked environment.

## Realtime and Storage

Realtime filters reduce traffic but are not authorization. Reconcile reconnect/gaps from an authoritative version/cursor, deduplicate events, and clean up channels. Storage policy must bind bucket, exact object/path ownership or tenant membership, and operation; service-created objects may not have a user owner, so define ownership explicitly. Upsert/replacement requires the effective `INSERT`, `SELECT`, and `UPDATE` policy paths, not only permission to create an object. Signed/public URLs follow product confidentiality policy.

## Verification and Output

Run repository checks plus local migration rebuild, generated-type diff, RLS/grant matrix, direct RPC/function invocation tests, Auth SSR/cookie tests, Edge Function unauthenticated/wrong-tenant tests, Storage cross-object tests, and Realtime reconnect tests. Verify the target environment after an authorized deploy and report untested hosted paths.

Return changed schema/code/types, subject/tenant/object authority, exposed-schema/grant/RLS matrix, function owner/search-path/grants, installed capability evidence, exact migration target and recovery, executed checks, and residual hosted risk.

Official sources: `https://supabase.com/docs/guides/api/securing-your-api`, `https://supabase.com/docs/guides/database/postgres/row-level-security`, `https://supabase.com/docs/guides/functions/auth`, `https://supabase.com/docs/guides/local-development/cli-workflows`, `https://supabase.com/docs/guides/auth/server-side/advanced-guide`.
