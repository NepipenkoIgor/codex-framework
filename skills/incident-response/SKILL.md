---
name: incident-response
description: Coordinate an active production incident through command, evidence, containment, recovery, verification and stakeholder communication. Use when a concrete incident requires response; not for speculative implementation or postmortem-only review.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.0
  argument-hint: "observed impact/timeline, exact environments/services, current commander/authority, recent changes and safe evidence sources"
---

Respond to $ARGUMENTS.

Establish incident commander, operations lead, communications owner, scribe, decision authority and secure channel appropriate to the team's actual process. Record UTC timeline, observed user/business impact, affected scope, release/config/provider identities and evidence provenance. Severity follows impact and trajectory, not a universal label.

Preserve evidence while protecting secrets/PII. Separate facts, hypotheses and decisions. Correlation with a deploy is not root cause. Run the smallest read-only checks that discriminate hypotheses; do not grep huge sensitive logs, expose credentials, restart broadly or execute guessed commands against ambiguous targets.

Contain the demonstrated failure with the least irreversible action. Resolve exact environment/resource/tenant/region, permissions, blast radius and recovery before mutation. Rollback is not universally safest: verify old code can read current schema/data/events/config/secrets and external side effects. Consider traffic isolation, feature/config control, dependency protection or roll-forward when compatible.

After partial/cancelled action, reconcile provider-visible state before retry. Verify caller-visible recovery, data integrity, queues/workers, dependencies, errors/latency/saturation and business invariants across affected slices; watch for recurrence. “Command succeeded” or health green is insufficient.

Communicate impact, scope, mitigations, evidence and next update time without speculative cause, secrets or unsupported ETA. After stabilization, preserve timeline/decisions, assign evidence-backed follow-ups and hand durable procedures to runbook-generation.

Report current state/roles, evidence and hypotheses, exact actions/authority, rollback compatibility, verification, communications and unresolved risks. Do not claim root cause until substantiated.
