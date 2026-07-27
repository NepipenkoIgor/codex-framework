---
name: search-implementation
description: Implement authorized application search, indexing, filtering, ranking, autocomplete, reindex, deletion, and relevance evaluation with the repository's selected engine. Use when search semantics dominate; do not use for ordinary database queries.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 1.5
  argument-hint: "engine/pins and source authority, actor/tenant/document auth, freshness/deletion, workload/features and relevance evidence"
---

# Search Implementation

1. Inspect source-of-truth ownership, engine/version/client pins, index mappings/analyzers, ingestion/checkpoints, auth/tenant model, query API, representative corpus/queries, privacy/deletion and telemetry. Preserve installed engine unless migration is explicit.
2. Define document identity/version/tenant/resource ownership and freshness/deletion contract. Index only authorized/minimized fields; protect raw source, snippets/highlights, facets/counts, autocomplete and analytics from data leakage.
3. Enforce current authorization both in indexing policy and every query/result path. Client filters or tenant fields are not authority; stale permissions require deletion/update or query-time enforcement with tested lag.
4. Make ingestion at-least-once safe with idempotent versioned upsert/delete, checkpoint and reconciliation. Handle out-of-order updates, missed deletes, source/index drift and privacy erasure across aliases/replicas/backups/analytics.
5. Reindex into a separate versioned target, validate mappings/counts/sample auth/relevance, dual-write or catch up safely, atomically switch where supported, retain rollback and clean old indexes after acceptance. Never delete the active index first.
6. Derive ranking, analyzers, typo/synonym/facet/autocomplete and latency targets from representative queries and product judgments. No engine, document count, shard size, debounce, boost or relevance threshold is universal.

Verify cross-tenant/private-document leakage, field/facet/count/snippet leaks, stale permission/deletion, duplicate/out-of-order indexing, checkpoint loss, live writes during reindex, rollback, query injection/cost, pagination and a versioned relevance set with judged top results/metrics.

Report engine/pins, source/index/auth contract, ingestion/freshness/deletion/reindex, query/cost controls, relevance evidence, checks/results and residual lag/provider risk.
