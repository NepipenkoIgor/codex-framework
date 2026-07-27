---
name: kubernetes-workload
description: Implement Kubernetes workload manifests, Helm/Kustomize overlays, autoscaling, disruption, networking, identity, health, rollout and shutdown behavior. Use when Kubernetes workload repository changes are requested.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.0
  argument-hint: "cluster/version, workload/SLO, observed CPU-memory-latency, dependencies, traffic and failure model"
---

Implement the Kubernetes workload for $ARGUMENTS.

## Discover cluster and workload contracts

Read instructions, charts/manifests/overlays, image/build provenance, Kubernetes and controller versions, namespaces, service accounts/RBAC, Services/Ingress/Gateway, NetworkPolicies/CNI/DNS, storage, autoscaling, disruption and observability. Before material mutation, resolve the exact target, workload/platform owner, write/apply authority and permissions, and a tested rollout rollback/recovery; do not apply externally unless explicitly authorized.

Preserve installed APIs and verify version/capability from cluster discovery, schemas or matching official docs. Pin deployable images by immutable digest or repository release policy; avoid mutable tags. For greenfield tooling use `scripts/framework-stack-context.py`.

## Workload safety

- Set requests from measured steady/startup behavior and scheduler needs; set limits from runtime/container behavior, node capacity and OOM/throttling evidence. No universal CPU/memory ratio.
- Configure HPA/VPA/custom metrics from the real demand signal, stabilization, startup and downstream capacity. Min/max and targets come from load evidence and SLOs.
- PDB and rollout availability must reflect replica count, failure domains, voluntary disruptions and drain capacity. A PDB can block maintenance and cannot protect against all failures.
- Health endpoints distinguish startup, readiness and liveness. Readiness reflects ability to serve; liveness does not use fragile dependencies that cause restart storms. Align termination grace, preStop/drain, load-balancer removal, connection/queue handling and job idempotency with measured shutdown.
- NetworkPolicy semantics depend on actual CNI, selectors, namespaces, DNS and ingress/egress paths. Prove DNS and required provider endpoints; do not assume policy alone isolates traffic.
- Use a dedicated least-privilege service account and RBAC verbs/resources/namespaces. Avoid default service-account tokens, cluster-admin and wildcards unless exact necessity is proven.
- Protect secrets/config, security context, volumes, topology and disruption according to workload threat/recovery requirements.

## Verification and output

Render and schema/policy validate manifests, diff the exact target, and test scheduling, startup/readiness/liveness, load/autoscaling, rollout, drain/termination, disruption, DNS/network policy, RBAC denial, secret/config changes and rollback in an owned environment. Report cluster/version evidence, measured resource/autoscaling decisions, network/RBAC paths, image provenance, changes, checks and unapplied/external risks.
