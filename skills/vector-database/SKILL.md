---
name: vector-database
description: Design and implement vector storage and similarity retrieval across pgvector, Pinecone, Qdrant, Weaviate, Chroma, or Milvus. Use when embedding search requires measured recall, filtering, scale, and lifecycle behavior; do not use when relational or full-text search is sufficient.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 3.0
  argument-hint: "corpus, embedding model/dimensions, filters, scale, recall/latency target, lifecycle"
---

# Vector Database

First establish the non-vector baseline, representative evaluation queries, filters, corpus characteristics and lifecycle contract below. Then read [the full provider guide](references/full-guide.md) when the task selects, compares, tunes, migrates, or evaluates a database/index candidate; skip it when no provider/index decision or detail is needed.

Read repository instructions, then generate project stack context and inspect/preserve the installed client or extension and server/provider versions, runtime/deployment constraints, corpus/evaluation evidence, tenant authorization and lifecycle code, scale, adjacent tests, embedding model revision, preprocessing, dimensions, metric, filter-schema version, index generation, backup/restore capability and matching version-specific official provider/model documentation as one compatibility unit. Isolate volatile provider APIs, defaults and index controls behind a versioned adapter/configuration contract; migration or reindex is separate scope.

## Contract

- Establish a non-vector baseline and evaluation set before selecting infrastructure.
- Persist immutable compatibility/index-generation metadata containing client/extension/server identity, embedding model revision, dimensions, preprocessing, metric, filter-schema version and index generation.
- Keep stable source/document/chunk identifiers so re-embedding and deletion are deterministic.
- Authenticate the actor and derive tenant/resource authorization server-side for every vector write, upsert, retrieval and delete; apply filters inside retrieval, not after returning cross-tenant candidates.
- Select distance metric and index parameters through measured recall/latency/cost tradeoffs.
- Define dual-write/reindex, consistency, backup, deletion, cache invalidation and provider-failure behavior. Authenticate deletion authority, persist a tombstone on stable source identity, stop retrieval across every serving API and active/old generation, and propagate deletion to derived queues/jobs, caches and restored/retained backups through policy-defined suppression or re-erasure.
- Prove deletion with negative retrieval through every API/generation, queue replay without resurrection, source/count reconciliation, and a documented backup suppression/erasure state plus restore test; active-index success alone is insufficient.

## Workflow

1. Define queries, relevance judgments, filters, corpus size/growth, and latency/cost targets.
2. Evaluate lexical, relational, vector, and hybrid baselines.
3. Implement versioned ingestion with idempotent upsert/delete and observable failures.
4. Tune candidate count, index, filtering, hybrid weighting, and optional reranking on held-out queries.
5. Test authenticated/unauthorized writes and deletes, tenant isolation, stale/missing embeddings, dimension mismatch, partial backfill, reindex cutover and rollback pointer, deletion through every API/generation plus queue replay, caches and backup restore, empty results, and provider outage.
6. Monitor recall proxy, latency percentiles, index growth, failed ingestion, and cost.

## Output Contract

- Baseline and provider/index decision
- Versioned schema and lifecycle
- Retrieval/evaluation results
- Isolation, recovery, cost, and residual relevance risk
