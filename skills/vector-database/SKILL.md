---
name: vector-database
description: Integrate vector databases for similarity search including pgvector (PostgreSQL), Pinecone, Qdrant, Weaviate, Chroma, and Milvus
metadata:
  version: 2.1
  argument-hint: "vector DB choice, embedding model, scale (vectors count), query patterns, latency targets"
---

Implement vector database integration for $ARGUMENTS.

## Documentation

> Use available docs lookup tools or official docs when you encounter unknown API syntax, current library versions, or framework-specific configuration. Do not rely on training data for library docs — fetch current docs on demand.

## Technology Selection

| Database | Type | Best For | Max Vectors | Hosting |
|----------|------|----------|-------------|---------|
| pgvector | PostgreSQL extension | Already using PG, <5M vectors | ~5M | Self-managed / Supabase |
| Pinecone | Managed SaaS | Serverless, zero-ops, production scale | Billions | Managed |
| Qdrant | Dedicated vector DB | High-performance, rich filtering | Billions | Self-hosted or cloud |
| Weaviate | Dedicated vector DB | Multi-modal, built-in vectorization | Billions | Self-hosted or cloud |
| Chroma | Embedded / lightweight | Prototyping, small datasets | ~1M | Embedded or server |
| Milvus | Dedicated vector DB | Massive scale, GPU support | Billions | Self-hosted or Zilliz Cloud |

Decision guide:
- Already on PostgreSQL + <1M vectors: pgvector (simplest, no new infrastructure)
- Already on PostgreSQL + 1-5M vectors: pgvector with HNSW index tuning
- Need zero-ops managed service: Pinecone Serverless
- Need rich filtering + high performance: Qdrant
- Need multi-modal (text + images): Weaviate
- Prototyping or local development: Chroma
- Massive scale (100M+ vectors): Milvus or Pinecone

## Index Types

### HNSW (Hierarchical Navigable Small World)

- Default for most vector databases -- best query performance
- Build time: slow (minutes to hours for large datasets)
- Query time: fast (sub-millisecond for <1M vectors)
- Memory: stores entire graph in memory -- higher memory usage
- Parameters:
  - `m` (max connections per node): 16-64. Higher = better recall, more memory. Default: 16
  - `ef_construction` (search width during build): 64-512. Higher = better recall, slower build. Default: 200
  - `ef_search` (search width during query): 64-512. Higher = better recall, slower query. Default: 100

### IVF (Inverted File Index)

- Clusters vectors into partitions, searches only relevant partitions
- Build time: fast (clustering step)
- Query time: moderate (depends on nprobe)
- Memory: lower than HNSW -- only centroids in memory, vectors on disk
- Parameters:
  - `nlist` (number of clusters): sqrt(N) to 4*sqrt(N) where N = total vectors
  - `nprobe` (clusters to search): 1-nlist. Higher = better recall, slower. Default: 10-20% of nlist
- Use when: memory-constrained, very large datasets, acceptable latency trade-off

### Flat (Brute Force)

- Exact nearest neighbor search -- 100% recall
- No build time, no parameters
- Query time: O(N) -- only viable for <100K vectors
- Use when: small dataset, perfect recall required, or as a baseline for benchmarking

### Index Selection Guide

| Dataset Size | Recommended Index | Why |
|-------------|-------------------|-----|
| <100K | Flat or HNSW (low m) | Brute force is fast enough; HNSW adds marginal latency benefit |
| 100K-1M | HNSW | Best recall/latency trade-off |
| 1M-10M | HNSW with tuned parameters | Increase m and ef for quality at scale |
| 10M-100M | IVF-HNSW hybrid or IVF-PQ | Memory optimization with acceptable recall |
| >100M | IVF-PQ or specialized (Milvus GPU) | Quantization required for memory |

## Distance Metrics

| Metric | Formula | Range | Use When |
|--------|---------|-------|----------|
| Cosine | 1 - cos(a, b) | [0, 2] | Normalized embeddings (most common) |
| Dot Product | -a . b | (-inf, inf) | Embeddings where magnitude matters |
| L2 (Euclidean) | sqrt(sum((a-b)^2)) | [0, inf) | Spatial data, non-normalized vectors |

Rules:
- Use cosine similarity for text embeddings (OpenAI, Cohere, etc.) -- they are normalized
- Use dot product when the embedding model documentation recommends it
- Use L2 for image embeddings or spatial coordinates
- Match the metric to what the embedding model was trained with

## pgvector Implementation

### Setup

```sql
-- Enable the extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Create table with vector column
CREATE TABLE documents (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  content TEXT NOT NULL,
  embedding vector(1536),       -- match your model's dimensions
  metadata JSONB DEFAULT '{}',
  source TEXT,
  created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- HNSW index (preferred for query speed)
CREATE INDEX idx_documents_embedding_hnsw
  ON documents USING hnsw (embedding vector_cosine_ops)
  WITH (m = 16, ef_construction = 200);

-- IVF index (alternative for large datasets)
-- CREATE INDEX idx_documents_embedding_ivf
--   ON documents USING ivfflat (embedding vector_cosine_ops)
--   WITH (lists = 1000);

-- Metadata index for filtered queries
CREATE INDEX idx_documents_metadata ON documents USING gin (metadata);
CREATE INDEX idx_documents_source ON documents (source);
```

### Query Patterns

```sql
-- Similarity search with cosine distance
SELECT id, content, metadata, 1 - (embedding <=> $1::vector) AS similarity
FROM documents
WHERE metadata->>'category' = 'api-docs'
ORDER BY embedding <=> $1::vector
LIMIT 10;

-- Hybrid search: vector + full-text
SELECT id, content,
  (1 - (embedding <=> $1::vector)) * 0.7 +
  ts_rank(search_vector, plainto_tsquery('english', $2)) * 0.3 AS score
FROM documents
WHERE search_vector @@ plainto_tsquery('english', $2)
ORDER BY score DESC
LIMIT 10;

-- Set HNSW ef_search for this session (higher = better recall, slower)
SET hnsw.ef_search = 200;
```

### pgvector Rules

- Always create an index -- without one, every query is a full table scan
- Use `vector_cosine_ops` for cosine distance, `vector_l2_ops` for L2, `vector_ip_ops` for inner product
- Set `hnsw.ef_search` higher (200-400) when recall matters more than latency
- Vacuum the table after large batch inserts to update index statistics
- For >5M vectors: consider migrating to a dedicated vector database

### Batch Upsert

```typescript
// pgvector batch upsert with pg driver
async function upsertDocuments(docs: { id: string; content: string; embedding: number[]; metadata: object }[]) {
  const ids = docs.map(d => d.id);
  const contents = docs.map(d => d.content);
  const embeddings = docs.map(d => `[${d.embedding.join(',')}]`);
  const metadatas = docs.map(d => JSON.stringify(d.metadata));
  await pool.query(
    `INSERT INTO documents (id, content, embedding, metadata)
     SELECT * FROM unnest($1::text[], $2::text[], $3::vector[], $4::jsonb[])
     ON CONFLICT (id) DO UPDATE SET content = EXCLUDED.content, embedding = EXCLUDED.embedding, metadata = EXCLUDED.metadata`,
    [ids, contents, embeddings, metadatas]
  );
}
```

## Pinecone Implementation

### Setup and Upsert

```typescript
import { Pinecone } from '@pinecone-database/pinecone';

const pinecone = new Pinecone({ apiKey: process.env.PINECONE_API_KEY! });
const index = pinecone.index('my-index');

// Batch upsert (max 100 vectors per request for serverless)
async function upsertBatch(vectors: { id: string; values: number[]; metadata: Record<string, unknown> }[]) {
  const batchSize = 100;
  for (let i = 0; i < vectors.length; i += batchSize) {
    const batch = vectors.slice(i, i + batchSize);
    await index.namespace('default').upsert(batch);
  }
}

// Query with metadata filter
async function query(embedding: number[], filter?: Record<string, unknown>, topK = 10) {
  const results = await index.namespace('default').query({
    vector: embedding,
    topK,
    filter,
    includeMetadata: true,
  });
  return results.matches ?? [];
}

// Delete by metadata filter
async function deleteBySource(source: string) {
  await index.namespace('default').deleteMany({ source });
}
```

### Namespace Design

- Use namespaces to isolate tenants, environments, or document collections
- Queries are scoped to a single namespace -- no cross-namespace search
- Namespace per tenant for multi-tenant applications
- Namespace per environment: `production`, `staging`, `development`

## Qdrant Implementation

### Setup and Operations

```typescript
import { QdrantClient } from '@qdrant/js-client-rest';

const client = new QdrantClient({ url: process.env.QDRANT_URL!, apiKey: process.env.QDRANT_API_KEY });

// Create collection
await client.createCollection('documents', {
  vectors: { size: 1536, distance: 'Cosine' },
  optimizers_config: { indexing_threshold: 20000 },
  hnsw_config: { m: 16, ef_construct: 200 },
});

// Create payload index for filtered search
await client.createPayloadIndex('documents', {
  field_name: 'source',
  field_schema: 'keyword',
});

// Batch upsert
async function upsert(points: { id: string; vector: number[]; payload: Record<string, unknown> }[]) {
  await client.upsert('documents', { wait: true, points });
}

// Query with filter
async function search(vector: number[], filter?: object, limit = 10) {
  return client.search('documents', {
    vector,
    limit,
    filter: filter ? { must: [filter] } : undefined,
    with_payload: true,
  });
}
```

### Qdrant Filtering

```typescript
// Rich filtering examples
const filter = {
  must: [
    { key: 'source', match: { value: 'api-docs' } },
    { key: 'updated_at', range: { gte: '2025-01-01T00:00:00Z' } },
  ],
  must_not: [
    { key: 'status', match: { value: 'archived' } },
  ],
};
```

## Metadata Filtering

### Schema Design

Keep metadata flat and typed for efficient filtering:

```typescript
interface ChunkMetadata {
  source: string;           // "docs/api-reference.md"
  section: string;          // "Authentication"
  page: number;             // 42
  chunk_index: number;      // 3
  category: string;         // "api-docs"
  language: string;         // "en"
  updated_at: string;       // ISO 8601
  token_count: number;      // 512
}
```

Rules:
- Index metadata fields used in filters -- unindexed filtering is slow
- Keep metadata values low-cardinality for keyword filters (category, status, type)
- Use range filters for numeric and date fields
- Avoid deeply nested metadata -- most vector DBs support only flat or shallow filtering
- Include `token_count` in metadata for context window budgeting

## Hybrid Search (Vector + Keyword)

### Implementation Pattern

```typescript
// pgvector hybrid search with RRF
async function hybridSearch(query: string, queryEmbedding: number[], topK: number = 10) {
  const results = await pool.query(`
    WITH vector_results AS (
      SELECT id, content, metadata,
        ROW_NUMBER() OVER (ORDER BY embedding <=> $1::vector) AS vector_rank
      FROM documents
      ORDER BY embedding <=> $1::vector
      LIMIT 50
    ),
    keyword_results AS (
      SELECT id, content, metadata,
        ROW_NUMBER() OVER (ORDER BY ts_rank(search_vector, plainto_tsquery('english', $2)) DESC) AS keyword_rank
      FROM documents
      WHERE search_vector @@ plainto_tsquery('english', $2)
      LIMIT 50
    )
    SELECT
      COALESCE(v.id, k.id) AS id,
      COALESCE(v.content, k.content) AS content,
      COALESCE(v.metadata, k.metadata) AS metadata,
      COALESCE(1.0 / (60 + v.vector_rank), 0) + COALESCE(1.0 / (60 + k.keyword_rank), 0) AS rrf_score
    FROM vector_results v
    FULL OUTER JOIN keyword_results k ON v.id = k.id
    ORDER BY rrf_score DESC
    LIMIT $3
  `, [JSON.stringify(queryEmbedding), query, topK]);

  return results.rows;
}
```

Rules:
- Use hybrid search when users may search for specific terms (product names, error codes, IDs)
- RRF constant `k=60` is the standard default -- tune if needed
- Weight vector vs keyword results based on your use case (0.7/0.3 is a common starting point)
- Pinecone and Qdrant support hybrid search natively via sparse vectors or keyword indexes

## Collection / Namespace Design

### Multi-Tenant Patterns

| Pattern | Isolation | Complexity | Cost |
|---------|-----------|------------|------|
| Metadata filter per tenant | Low (shared index) | Low | Lowest |
| Namespace per tenant | Medium (logical separation) | Medium | Medium |
| Collection per tenant | High (physical separation) | High | Highest |

Rules:
- Metadata filtering: simplest, works for <100 tenants with moderate data
- Namespace per tenant: good balance for SaaS products, supported by Pinecone and Qdrant
- Collection per tenant: strongest isolation, use when data sensitivity requires it
- Always include tenant ID in queries regardless of pattern -- defense in depth

## Migration Patterns

### Between Vector Databases

```
1. Export from source:
   - Read all vectors with metadata in batches (1000-5000 per batch)
   - Store as JSONL or Parquet intermediate format

2. Transform if needed:
   - Map metadata schema to target format
   - Adjust vector dimensions if target requires it

3. Import to target:
   - Create collection/index with correct dimensions and distance metric
   - Batch upsert with progress tracking
   - Verify count matches source

4. Validate:
   - Run evaluation queries against both old and new stores
   - Compare recall and latency metrics
   - Switch traffic via feature flag
```

### Version Migration (Re-embedding)

When switching embedding models:
1. Create a new collection with the new model's dimensions
2. Re-embed all documents with the new model (batch processing)
3. Verify quality with evaluation queries
4. Switch traffic to the new collection
5. Delete the old collection after validation

## Scaling Strategies

### Horizontal Scaling

- Pinecone: scales automatically (serverless) or via pod replicas
- Qdrant: sharded collections across nodes, replication for HA
- pgvector: read replicas for query scaling, partitioning for write scaling
- Milvus: distributed architecture with query nodes, data nodes, index nodes

### Cost Optimization

- Use dimensionality reduction: OpenAI text-embedding-3-large supports `dimensions` parameter
- Use scalar quantization (int8) for 4x memory reduction with <5% recall loss
- Use product quantization (PQ) for 8-32x compression on very large datasets
- Archive stale vectors to cold storage; keep only active documents indexed
- Monitor query patterns: if most queries use metadata filters, invest in efficient filtering rather than larger indexes

## Anti-Patterns

- Mismatched distance metric between index and query -- similarity scores are meaningless
- Embedding with one model and querying with another -- vectors are incompatible
- No metadata indexes for filtered queries -- filter operations scan all vectors
- Single collection for all tenants without row-level filtering -- data leakage risk
- Ignoring index build time -- HNSW on 1M+ vectors takes significant time
- Not monitoring recall -- index parameter drift degrades quality silently

## Implementation Workflow

1. Choose vector database based on dataset size, existing infrastructure, and requirements
2. Create collection/table with correct dimensions and distance metric
3. Configure index type and parameters (HNSW m, ef_construction for most cases)
4. Add metadata payload indexes for filtered search fields
5. Implement batch upsert with progress tracking
6. Implement query with metadata filtering and top-K
7. Add hybrid search if keyword matching is needed
8. Set up incremental updates (upsert changed, delete removed)
9. Benchmark recall and latency with representative queries
10. Monitor index size, query latency, and recall over time

## Output Format

For each vector database implementation:

```
Database:          [pgvector / Pinecone / Qdrant / Weaviate / Chroma / Milvus]
Dimensions:        [embedding dimensions]
Distance Metric:   [cosine / dot / L2]
Index Type:        [HNSW / IVF / Flat]
Index Parameters:  [m, ef_construction, ef_search / nlist, nprobe]
Collection Design: [single / per-tenant namespace / per-tenant collection]
Metadata Schema:   [indexed fields and types]
Hybrid Search:     [vector-only / vector + keyword with RRF]
Batch Size:        [upsert batch size]
Estimated Scale:   [current and projected vector count]
```

## Done Criteria

- Vector index created with appropriate type, parameters, and distance metric
- Batch upsert handles the target document volume without timeout
- Similarity search returns relevant results within acceptable latency (<100ms for <1M vectors)
- Metadata filtering works for all required filter dimensions
- Hybrid search combines vector and keyword results when applicable
- Multi-tenant isolation enforced via namespace, collection, or metadata filter
- Incremental updates work: upsert changed documents, delete removed ones
- Index recall benchmarked against a test set (>0.9 for HNSW with default params)
- Monitoring in place: query latency, index size, vector count
