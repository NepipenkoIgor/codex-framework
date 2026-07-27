---
name: distributed-coordination
description: Implement distributed ownership for locks, leases, leader election, singleton scheduling, and deduplicated critical sections with fencing and recovery. Use when multiple processes can concurrently mutate one protected resource; do not use for local mutexes, queue consumption alone, or transactions confined to one database.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  argument-hint: "protected resource, contenders, coordination store, lease/fencing support, side effects, failover"
---

# Distributed Coordination

Implement `$ARGUMENTS` from the protected invariant and failure model, not from a lock recipe.

## Workflow

1. Inspect repository/runtime pins, topology, contenders, exact coordination-store version and configured quorum/consistency capability, time source, transaction boundary, downstream write paths, deployment termination/failover, and existing tests plus telemetry. Prefer a single-database uniqueness or atomic update when it fully protects the invariant.
2. Define the exact resource key, ownership record, acquisition linearization point, lease/expiry behavior, renewal, fencing token or monotonic epoch, release, failover, and recovery. Document what remains possible during process pause, partition, store failover, and ambiguous response.
3. Treat TTL as liveness, not safety. A paused or partitioned owner can resume after expiry while a new owner is active. Every protected state write must reject a stale fencing token/epoch at the authoritative resource, or the design must use another proven serialization mechanism.
4. Acquire and renew with the configured store version's documented atomic/consistency primitives. Derive lease TTL and renewal margin from measured critical-section duration, observed pauses/network delay and recovery objective; derive quorum/consistency configuration from the installed store capability and failure model. Local timers and wall clocks do not prove ownership. Stop protected work immediately when renewal is late, rejected, ambiguous, or connectivity prevents current ownership proof.
5. Keep the critical section bounded and cancellation-aware. On graceful shutdown stop new acquisition, cancel protected work, and release only the ownership record that still matches this owner/token. Expiry remains the crash recovery path.
6. External side effects need their own durable business-operation idempotency and reconciliation. Holding a lease cannot roll back a provider charge, email, or transfer, and crashing after provider success cannot be repaired by reacquiring the lock and repeating blindly.
7. Leader election separates leadership from correctness: every command/write is scoped to an epoch, followers reject stale leaders, and failover is safe under overlapping old/new processes. Availability policy defines whether to fail closed when coordination is unavailable.
8. Verify pause beyond TTL, renewal failure, network partition, store failover, stale-owner write, concurrent acquisition, release-after-reacquire, process crash at each boundary, provider success before local crash, and recovery/reconciliation.

## Required counterexamples

- Worker A pauses beyond TTL; worker B acquires; A resumes. A's stale fenced write must be rejected.
- Store failover or an ambiguous acquire response cannot be treated as ownership without documented consistency evidence.
- Crash after a charge succeeds but before local completion must reconcile by business operation instead of charging again under a new lock.
- Renewal failure must stop the critical section; logging and continuing violates exclusivity.
- Deleting a lock key on shutdown without owner/token comparison can release another worker's lease.

## Output

Report the protected invariant and resource key, store/capability evidence, acquire/renew/release linearization, fencing enforcement point, failure and failover policy, side-effect idempotency/reconciliation, shutdown behavior, and remaining availability or provider risk. Enumerate executable fault-injection evidence separately for pause beyond TTL, renewal loss, network partition, store failover/ambiguity, stale write, concurrent acquire, release-after-reacquire, process death, shutdown, and recovery; do not collapse network partition into a residual-risk note.

## Provenance

- etcd API guarantees and leases: https://etcd.io/docs/v3.5/learning/api_guarantees/
- etcd concurrency lock ownership: https://etcd.io/docs/v3.5/dev-guide/api_concurrency_reference_v3/
