---
name: saas-starter
description: Plan and scaffold a greenfield SaaS foundation across identity, tenant or subject, entitlement, billing, activation, and operations after selecting the repository stack. Use only when the request spans several SaaS foundations from zero; do not use for an existing product or a single onboarding, billing, membership, tenancy, or generic repository-setup task.
metadata:
  owner: codex-framework
  reviewed: "2026-09-19"
  version: 2.1
  argument-hint: "product model, B2C/B2B, stack constraints, billing and activation needs"
---

Create the smallest greenfield SaaS foundation for `$ARGUMENTS`.

## Workflow

1. Confirm this is a new product spanning multiple foundations. For an existing repository or one capability, route to the owning domain skill.
2. Decide B2C versus B2B, the security tenant and identity subject, organization/membership need, and authorization authority.
3. Define entitlement and billing authority, lifecycle and reconciliation boundaries; do not copy provider tables or webhook code before those decisions.
4. Define activation/onboarding progress and the minimum caller-visible product journey.
5. Select required operational controls: audit evidence, privacy, observability, recovery, environment and deployment. Treat compliance and pricing assumptions as external decisions.
6. Resolve stable/LTS context for a new stack at execution time from configured official sources, verify runtime/framework/database/provider/test/deployment compatibility as one unit, then generate manifests/lockfiles and make those artifacts authority. Do not force Next.js, Supabase, PostgreSQL, Stripe, fixed roles, plans, tables, or directory layouts.
7. Scaffold one vertical slice using generated manifests and lockfiles as the new source of truth; expand only after validation.
8. Verify authorization, tenant/subject isolation, replay/idempotency, billing/entitlement convergence, onboarding resume, failure recovery, and the repository's build/tests. Distinguish supplied facts from prudent test hypotheses: do not attribute concurrent processing or any other failure condition to the task unless its evidence says so; when overlap is merely possible, label concurrency as a hypothesis to test.

## Output

Report product and authority decisions, selected stack/version evidence, minimal schema and boundaries, generated files, vertical-slice behavior, checks, operational gaps, and explicit follow-up domains.
