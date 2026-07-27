# Vector Store Provider and Index Guide

Load this guide after the main skill establishes a non-vector baseline, evaluation queries, filters and corpus characteristics whenever selecting, comparing, tuning, migrating or evaluating a provider/index candidate. Inspect the installed client/extension/server version and current official documentation; do not copy remembered defaults, capacity limits or API signatures.

## Provider Decision

Compare the repository's existing relational/search platform with managed and self-hosted vector stores on measured filtered recall, latency distribution, ingestion/update/delete behavior, tenant isolation, consistency, backup/restore, regional/privacy needs, operations and cost. A provider marketing scale claim is not workload evidence.

## Versioned Schema

Treat this tuple as one compatibility unit:

```text
embedding_provider/model/revision + dimensions + preprocessing + distance metric
+ chunker/schema version + source/chunk identity + metadata/filter schema + index generation
```

Reject dimension/model/version mismatch before query or write. Use stable tenant/source/document/chunk identities and an idempotent source version so re-embedding, replacement and deletion are deterministic.

## Authorization and Filtering

- Authenticate and authorize the caller/resource before retrieval. Put mandatory tenant, environment, ACL and lifecycle filters inside the provider query; never fetch cross-tenant candidates and filter afterward.
- Treat namespaces/collections as provider capabilities, not automatic security. Bind every query/upsert/delete to a server-derived tenant scope and test bypass through alternate APIs, missing filters and malformed metadata.
- Return no existence, score or metadata leakage for unauthorized documents. Reauthorize source content before privileged downstream use where permissions may have changed.

## Index Choice and Tuning

- Exact/flat search is the evaluation baseline where feasible. Approximate indexes such as HNSW/IVF/PQ trade recall, latency, build/update cost and memory; select and tune parameters on representative filtered queries and production-like corpus/hardware.
- Match the distance metric to the embedding model documentation and provider implementation. Do not assume all text vectors are normalized or all image vectors require a particular metric.
- Measure recall against relevance judgments or an exact baseline, latency percentiles, filter selectivity, empty-result behavior and cost. Repository acceptance gates replace universal dataset-size or latency thresholds.

## Migration and Lifecycle

1. Create a new immutable index generation for schema/embedding/index changes. Do not mix incompatible vectors.
2. Backfill from authoritative source data with checkpointed idempotent ingestion and per-source failure evidence.
3. Dual-read or shadow representative queries; compare recall, filters, latency and missing/stale documents. Dual-write only with a defined ordering/reconciliation contract.
4. Switch reads through a reversible generation pointer after gates pass; preserve rollback while writes/deletes remain consistent.
5. Propagate source deletion, tenant deletion, retention and legal erasure to active and old generations, queues, caches, backups and derived indexes with verifiable tombstone/completion state.

## Provider-Specific Verification

For pgvector, Pinecone, Qdrant, Weaviate, Chroma or Milvus, retrieve the installed-version docs for index creation, filter syntax, consistency, pagination, delete semantics, limits and backup. Keep volatile examples out of the main skill. Test provider outage, partial batch, duplicate write, stale replica, index rebuild, restore and migration rollback.

Official sources: [pgvector](https://github.com/pgvector/pgvector), [Pinecone docs](https://docs.pinecone.io/), [Qdrant docs](https://qdrant.tech/documentation/), [Weaviate docs](https://docs.weaviate.io/), [Chroma docs](https://docs.trychroma.com/), and [Milvus docs](https://milvus.io/docs).
