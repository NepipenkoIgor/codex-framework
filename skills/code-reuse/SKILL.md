---
name: code-reuse
description: Consolidate demonstrated duplicate knowledge into the smallest stable abstraction while preserving bounded-context ownership and behavior. Use when reuse or duplication reduction is the primary requested outcome; not when similarity is incidental.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 3.0
  argument-hint: "duplicate locations, owners/bounded contexts, behavior to preserve, expected divergence and dependency constraints"
---

Improve reuse for $ARGUMENTS.

## Decide whether duplication is harmful

Read instructions, exact target implementations and all callers, tests, public contracts, dependency graph, domain ownership and the authority/permissions to mutate each package. Establish a recoverable incremental rollback path before extraction. Compare semantics, change cadence, invariants, validation/error/auth/data behavior and likely evolution. Repeated lines are not necessarily repeated knowledge; duplication across bounded contexts may be intentional isolation.

Classify the candidate as accidental copy, stable shared rule, presentation similarity, framework boilerplate, generated code, compatibility fork or independently evolving domain behavior. Search for an existing owned abstraction before creating another.

## Extract the smallest stable boundary

- Prefer a focused function, schema, component, fixture or service owned by the domain that defines the invariant.
- Keep domain-specific behavior inside its bounded context. Cross-package reuse needs a clear owner, compatibility contract and allowed dependency direction.
- Avoid generic “shared”, boolean-flag APIs, callback mazes, premature frameworks and base classes that couple unrelated lifecycles.
- Two examples are not proof of a reusable concept. Leave duplication when extraction increases coupling, hides policy or variants are likely to diverge.
- Preserve authorization, validation, transaction, accessibility, error, observability and performance semantics. A reuse refactor must not silently standardize intentionally different behavior.

Existing project versions and APIs remain authoritative; verify version-specific abstractions from local types/tests or matching docs, and keep any migration separate.

## Verification and output

Characterize each variant before changing it, refactor incrementally, and run focused plus affected tests/type/build checks for every caller and package boundary. Explicitly prove authorization, validation, error and data behavior for every variant, plus cycles, bundle/runtime expansion, rollback and public API compatibility. Report candidates, ownership/evolution evidence, extract/reuse/leave decision, changes, actual checks and residual coupling/divergence risk.
Distinguish artifacts actually inspected from artifacts merely known to exist; report unperformed reads and checks as pending, never as completed inspection or verification.
