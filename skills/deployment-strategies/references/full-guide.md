# Deployment strategy deep dive

Use only after the main workflow selects a candidate strategy.

- Blue-green requires duplicate capacity, traffic/session behavior, warmup, data compatibility and a retained recoverable environment. Switching traffic is not database rollback.
- Canary requires representative assignment, enough observations, stable control comparison and prevention of cross-cohort data/session contamination. Choose cohort and duration from risk and volume.
- Rolling updates require mixed-version compatibility, surge/unavailable capacity, readiness, drain and topology analysis.
- Feature flags require server-side authorization where consequential, configuration provenance, stale-client behavior, ownership, expiry and rollback independent of binary deployment.
- GitOps reconciles desired state but does not validate caller-visible success. Protect repository/controller credentials, approvals and drift semantics.

For every strategy, model schema/API/event compatibility, background workers, caches, queues, external side effects, telemetry gaps, low-volume evidence, stop/promotion authority and recovery when automated rollback fails. No universal percentage, dwell time, threshold or rollback duration applies.
