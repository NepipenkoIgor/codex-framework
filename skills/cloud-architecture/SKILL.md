---
name: cloud-architecture
description: Design read-only cloud landing zones, account/project hierarchy, identity and network trust, shared services, residency, failure isolation, recovery and cost ownership. Use when cross-workload cloud topology is undecided; use infrastructure-as-code for accepted implementation.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.0
  argument-hint: "providers/organizations, workloads and owners, actors/data residency, failure/recovery, latency/compliance and cost evidence"
---

Design cloud architecture for $ARGUMENTS without creating or changing cloud resources.

Inspect repository and supplied provider evidence for organizations/accounts/projects/subscriptions, federation and break-glass, workloads/data flows, regions/residency, networks/DNS/egress, shared services, policy/audit, IaC/state, recovery, quotas and billing ownership. Label missing provider/runtime evidence and do not invent current limits or API features.

Define assets, actors and human/workload/automation/support identities; data classification and residency/transfer; trust and privilege boundaries; blast radius and lifecycle; latency/availability objectives; provider/region/service failure modes; recovery/bootstrap/removal; and accountable cost allocation before choosing topology.

Compare alternatives using evidence: isolation, operational complexity, quota/cost, data movement, central-service dependency, incident containment and exit/recovery. Shared services can become cross-account privilege or availability bottlenecks. Policy inheritance, exceptions and break-glass need auditable ownership and recovery.

Preserve installed/provider capability context and resolve current limits, residency/identity features and pricing only from authoritative sources at execution time. Record source and retrieval timestamp or provider effective date for every volatile capability/limit used. Estimate cost with stated usage assumptions and uncertainty; list excluded transfer/support/observability/recovery costs.

Produce an ADR-ready decision, staged adoption and validation: cross-boundary denial, federation/least privilege, DNS/egress/private access, residency, logging visibility, bootstrap/removal, quota/cost attribution and regional/provider recovery. Hand accepted resource changes to `infrastructure-as-code` with exact targets and approvals.

Report discovered topology/provenance, requirements/assumptions, options, chosen boundaries, failure and recovery model, cost ranges/owners, validation and residual provider/data risks.
