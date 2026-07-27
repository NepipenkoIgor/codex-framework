---
name: frontend-architecture
description: Design a frontend application's smallest sufficient boundaries for modules, state, routing, data, forms, security, testing, and delivery. Use when an architecture decision or design artifact is requested; do not use for implementation or routine code review.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  argument-hint: "product workflows, existing stack, constraints, team/deployment context, unresolved decisions"
---

# Frontend Architecture

This is a design-only, read-only workflow. Inspect repository instructions, architecture, manifests/lockfiles, API schemas, deployment/runtime constraints, user flows and tests; do not edit the repository or create external resources. Generate installed stack context with `python3 scripts/framework-stack-context.py project <path>` or greenfield context with `python3 scripts/framework-stack-context.py latest <technologies...>`. A newer stable release does not authorize migration.

## Principles

- Choose the smallest architecture that satisfies demonstrated product workflows and quality constraints. Extend existing boundaries when they are adequate; every new layer, store, abstraction, package or runtime boundary needs a concrete pressure and deletion/evolution story.
- Separate durable domain/server state, URL state, transient UI state, form drafts and derived state. Keep state closest to its authoritative owner and avoid synchronized copies.
- The server remains authoritative for authentication, authorization, tenant/object access, protected fields, validation and side effects. Route guards and hidden controls are UX only.
- Queries and mutations have different semantics. Define cache identity, freshness/invalidation and request cancellation for reads. Define stable operation identity, server idempotency, unknown-outcome reconciliation, concurrency/conflict and compensation for retryable mutations; a disabled button is not correctness.
- Framework capabilities are inputs, not architecture goals. Keep volatile implementation recipes in the relevant implementation skill, especially Next.js App Router mechanics.

## Workflow

1. Establish decision drivers and record the inspected evidence for concrete user flows, API schemas/server contracts and team/package ownership: users/workflows, domain boundaries, sensitive data, offline/real-time needs, scale evidence, latency/reliability, accessibility/i18n, team ownership, deployment and migration constraints. Mark any unavailable source as an unresolved input rather than inventing it.
2. Map existing modules and runtime boundaries, server contracts, shared primitives, state/data flow, failure paths and test seams. Identify the smallest unresolved decisions.
3. Produce two or more credible options only where a real tradeoff exists. Compare operational complexity, security, delivery cost, coupling, testability, migration and reversibility; recommend one with explicit rejected alternatives.
4. Define feature/module public contracts, route ownership, state map, server/API boundary, form/mutation behavior, errors/loading/empty states, observability and test distribution.
5. Sequence adoption in reversible slices with compatibility and rollback. Avoid a full rewrite unless constraints prove incremental migration inadequate.

## Required Security and Reliability Questions

- Where is each identity/permission decision enforced server-side, and how does UI recover from revoked/stale permissions?
- What data may enter the client, caches, telemetry and persisted drafts? How are tenant and user partitions maintained?
- Which operations can retry, how is idempotency preserved, and how is a timeout-after-commit reconciled?
- What happens under partial failure, stale data, concurrent edits, offline transitions and version skew?

## Verification of the Design

- Produce an explicit trace matrix for representative read, successful mutation, validation failure, unauthorized target, conflict, timeout-after-commit and recovery. For each, walk route/page → feature/state → adapter/request → server authority/persistence → returned caller state across every proposed boundary and assign a measurable implementation gate.
- Map each material decision to existing repository evidence or a labeled assumption; state what experiment or implementation spike would resolve uncertainty.
- Check dependency/runtime capability against installed types and current official docs, plus build/test/deployment compatibility. Do not claim performance or maintainability without a measurable acceptance condition.

## Output Contract

- Context, constraints, evidence and assumptions
- Smallest recommended architecture and boundary/state diagrams where useful
- Security, mutation, failure and observability contracts
- Options/tradeoffs and explicit non-goals
- Incremental adoption, verification gates, rollback and unresolved decisions
