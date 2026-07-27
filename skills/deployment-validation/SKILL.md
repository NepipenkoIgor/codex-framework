---
name: deployment-validation
description: Validate an actual deployment using release identity, safe journeys, migrations, dependencies, telemetry, cohort evidence and rollback readiness. Use when an environment or release change has been deployed; use deployment-strategies for design only.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 3.0
  argument-hint: "exact release/environment, artifact/config/schema identity, critical journeys, cohorts/SLOs, rollback authority"
---

Validate the deployment requested in $ARGUMENTS.

Resolve exact environment, release/artifact digest, config/secret/schema versions, rollout cohort and deployment completion from provider-visible evidence. Confirm target ownership and authorization before external probes or rollback. Health/readiness and command success are inputs, not caller-visible proof.

Run reversible, least-privilege synthetic or approved test journeys for affected auth/read/write/business behavior. Verify dependencies, migrations and mixed-version data compatibility, background workers, queues/events, scheduled jobs, caches, callbacks and irreversible side effects. Never casually mutate customer state.

Compare errors, latency, saturation and business invariants to an appropriate baseline/control across affected tenant/region/platform slices. Promotion/stop thresholds and observation duration must have been defined from SLOs, volume and harm; do not invent fixed percentages or soak periods. For low-volume releases use targeted cohorts, synthetic probes, invariant checks and explicit missing-evidence risk.

Prove code/config/traffic rollback and data recovery compatibility. Do not promise a fixed rollback time. If rollback is authorized, record exact action and read back deployed identity; after partial/cancelled mutation reconcile actual state before retry.

Report identities/provenance, checks and journeys, cohort/volume evidence, compatibility/migration state, telemetry gaps, promotion/rollback decision, external actions and residual untested boundaries.

Read [references/full-guide.md](references/full-guide.md) only for the deployed platform/strategy deep dive; routine validation uses this main workflow alone.
