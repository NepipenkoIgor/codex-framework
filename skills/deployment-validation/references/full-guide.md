# Deployment validation deep dive

Use only for the selected deployed platform and rollout type.

Collect release/controller/provider status, artifact digest, configuration and schema identity, pod/instance events, dependency health, migration records, queues/workers and caller-visible synthetic journeys. Separate infrastructure readiness from application success.

For canary/blue-green/rolling/flagged rollouts, verify actual cohort assignment, sample volume, contamination, mixed-version compatibility, drain and control comparison. Choose thresholds and observation from predeclared SLO/business harm and detection power; low volume may remain inconclusive.

Validate rollback prerequisites before action: old artifact availability/integrity, config and secret compatibility, database expand/contract state, event consumers, external side effects and recovery ownership. Reconcile provider-visible state after cancellation or partial rollback. Preserve redacted evidence and state what was not tested.
