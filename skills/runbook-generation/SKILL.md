---
name: runbook-generation
description: Create executable operational runbooks for incidents, deployments, recovery and support using exact repository/provider evidence. Use when a runbook is the requested artifact; not for executing an active incident response.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 3.0
  argument-hint: "trigger and scope, exact environments/resources, authority/roles, repository commands/dashboards, rollback and drill target"
---

Create the runbook requested in $ARGUMENTS.

Read instructions, existing runbooks/templates, repository commands, deployment/IaC, dashboards/alerts, provider identifiers, ownership/escalation and recent drill/incident evidence. Report only artifacts actually supplied or observed; mark unavailable runbooks, deployment definitions, dashboards, alerts, ownership/escalation or drill evidence as blocking placeholders rather than claiming they were inspected. Resolve exact service/environment/account/region/cluster/namespace/resource and version context. Never invent commands, dashboards, contacts, thresholds, owners or rollback; unresolved placeholders remain blocking gaps, not executable steps.

State trigger, impact/scope, exclusions, authority and role, prerequisites, required access/tools, safety/data constraints and stop conditions. Every command must identify target, expected read-only/mutating effect, success/failure output and next branch. Prefer repository-native scripts and provider readback. Do not use broad wildcards, unresolved variables, destructive defaults, secrets/PII, or commands copied for another version.

Consequential steps require explicit approval, exact target confirmation, backup/recovery and idempotency/partial-failure handling. Rollback must be compatible with current schema/data/events/config/secrets and external side effects; include roll-forward or recovery when reversal is impossible. Cleanup affects only recorded run-owned resources.

Order diagnosis, containment, mitigation, verification, communications, escalation and recovery for a tired operator. Define caller-visible success plus data/queue/dependency checks; command exit zero alone is insufficient.

Dry-run or tabletop the runbook in an isolated/low-risk exact target. Validate command availability/help against installed versions, permissions denial, branch/stop behavior, rollback and evidence capture. Record drill date, participants/roles, results and unresolved gaps.

Output trigger/scope, preconditions/authority, exact branched steps, rollback/recovery, verification, communications/escalation, cleanup, drill evidence and blocking placeholders.
