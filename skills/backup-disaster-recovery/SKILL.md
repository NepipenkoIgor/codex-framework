---
name: backup-disaster-recovery
description: Design and verify backup, point-in-time recovery, failover and disaster recovery against business-approved RPO/RTO with isolated restore drills. Use when recoverability or continuity is the primary outcome.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.0
  argument-hint: "systems/assets, threats/failure domains, approved RPO/RTO, backup providers, exact drill target and authority"
---

Design or verify recovery for $ARGUMENTS.

Inventory authoritative data, schemas/configuration, object stores, identity/IAM/RBAC/RLS policies, secrets and encryption keys, certificates, DNS, queues/events and offsets, caches that carry state, infrastructure, external dependencies, owners and failure domains. A database backup alone is not system recovery.

Derive RPO/RTO by workload and failure scenario from business authority. Measure achieved data loss and elapsed time from incident declaration through caller-visible readiness and reconciled background processing; provider backup age or restore-job completion is not proof.

Select backup/PITR/replication, retention, immutability, encryption, key escrow/recovery and cross-account/region/provider isolation from threat, compliance, cost and objectives. Keep at least one copy isolated from production identity and deletion authority where required. Replication can replicate corruption or attacker actions and is not automatically a backup.

Before any drill, resolve the exact isolated target, owner, credentials, network and deletion boundary. Never overwrite production or use broad destroy cleanup. Restore in dependency order, including keys/secrets, identity policies and RLS, data/schema, queues/events/idempotency, object references, configuration and integrations. Validate security controls after restore so recovered data is not exposed by permissive defaults.

Exercise corrupt/incomplete backup, unavailable or rotated key, account/region loss, stale replica, missing IAM, queue replay/duplicates, external dependency loss, failover and failback. Record exact owned resources and clean them safely after evidence capture.

Report inventory/provenance, RPO/RTO authority, architecture and deletion isolation, exact restore order/commands and targets, drill timestamps/evidence, achieved loss/time, security and queue reconciliation, cleanup, failback/rollback and untested boundaries.
