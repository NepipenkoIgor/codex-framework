---
name: search-implementation
description: Implement search functionality using Elasticsearch, OpenSearch, Algolia, Meilisearch, PostgreSQL full-text search, or SQLite FTS for .NET, Node
metadata:
  version: 1.4
  argument-hint: "dataset size, search features (autocomplete/typo/filters), search engine choice, latency targets"
---

Implement search for $ARGUMENTS.

## Documentation

> Use available docs lookup tools or official docs when you encounter unknown API syntax, current library versions, or framework-specific configuration. Do not rely on training data for library docs — fetch current docs on demand.

## Technology Selection

| Technology | Best for | Latency | Complexity |
|------------|----------|---------|------------|
| PostgreSQL FTS | Small-medium datasets, already using PG | ~50ms | Low |
| Meilisearch | Easy setup, instant search, typo tolerance | ~20ms | Low |
| Algolia | SaaS, instant search, analytics | ~20ms | Low |
| Elasticsearch | Large datasets, complex queries, analytics | ~50ms | High |
| Typesense | Open-source Algolia alternative | ~20ms | Medium |

Decision: PG + <1M rows -> PG FTS. Need typo tolerance + simple setup -> Meilisearch/Typesense. Enterprise scale + aggregations -> Elasticsearch. Fully managed SaaS -> Algolia.

## Search Architecture

```
User Query -> Search API (validate, parse, rate limit)
  -> Query Processing (parse filters, spell check, synonym expansion)
  -> Search Engine -> Result Processing (highlight, facets, snippets, permissions)
  -> Search Analytics (log query, results count, click-through, zero-results)
```

Data flow: Source DB -> Change Detection (CDC/events/polling) -> Index Pipeline (transform, enrich) -> Search Index

## Relevance Tuning

### Field Boosting

```json
// Elasticsearch multi_match
{ "query": { "multi_match": {
    "query": "search terms",
    "fields": ["title^5", "tags^3", "description^2", "body^1"],
    "type": "best_fields", "tie_breaker": 0.3
}}}
```

PostgreSQL: use `setweight(to_tsvector(...), 'A')` for title, 'B' for tags, 'C' for description, 'D' for body.

### Custom Scoring

Combine text relevance with business signals using `function_score`:
- Popularity: `field_value_factor` with `log1p` modifier
- Recency: `gauss` decay on date field (scale: 30d)
- Featured: filter + weight boost
- Score mode: `sum`, boost mode: `multiply`

### Tuning Methodology

1. Collect 20-50 representative queries with expected top results
2. Evaluate ranking with nDCG or manual review
3. Adjust weights, re-evaluate, repeat
4. Monitor search analytics for regression after deployment

## Synonym Management

```json
// Elasticsearch synonym filter
{ "filter": { "synonym_filter": {
    "type": "synonym",
    "synonyms": ["laptop, notebook, portable computer", "js, javascript"]
}}}
```

Types: equivalent (`laptop, notebook`), explicit mapping (`js => javascript`), domain-specific.

Rules:
- Apply synonyms at QUERY time, not index time
- Store in external file, version alongside code
- Review zero-result queries weekly for missing synonyms

### Analysis Chain

Raw text -> Character filters (HTML strip) -> Tokenizer (standard) -> Token filters (lowercase, stemmer, stop words, synonyms) -> Indexed tokens.

## Multi-Language Search

- Per-language field sub-fields with language-specific analyzers (english, german, french)
- Always specify analyzer at query time
- Strategies: per-field language, per-index language, or `icu_analyzer` fallback

## Search Analytics

| Metric | Target |
|--------|--------|
| Zero-result rate | <5% |
| Click-through rate (top-3) | >30% |
| Query latency (p95) | <200ms |
| Refinement rate | <20% |

Track: SearchEvent (query, filters, results_count, latency_ms) and SearchClickEvent (search_event_id, result_id, result_position). Aggregate zero-result queries daily, prioritize by frequency.

## Zero-Results Handling

Strategy cascade:
1. Fuzzy matching (edit distance 1-2)
2. Relaxed matching (drop least important terms)
3. Did-you-mean (phrase suggester or `pg_trgm` similarity)
4. Related content (same category, popular items)
5. Search suggestions (popular queries matching prefix)

```json
// Elasticsearch fuzzy
{ "query": { "multi_match": {
    "query": "labtop", "fields": ["title^3", "description"],
    "fuzziness": "AUTO", "prefix_length": 2, "max_expansions": 50
}}}
```

## Faceted Search

Use aggregations for facet counts. Key behavior rules:
- Show counts: `Laptops (42)`
- Multi-select within facet: OR logic; between facets: AND logic
- Use `post_filter` to apply selected facet AFTER aggregations (accurate counts while filtering)
- Preserve facets across pagination, show active filters as removable chips

## Autocomplete

Two approaches:
- **Completion suggester**: fast prefix matching with fuzzy support and context filtering
- **Edge n-gram**: index-time n-grams (min: 2, max: 15) with standard search analyzer for more control

Frontend rules: debounce 200-300ms, start after 2-3 chars, max 5-8 suggestions, keyboard navigation, recent/popular searches, cancel previous request (AbortController).

## Index Management

### Zero-Downtime Reindexing

Use alias-based index swapping: create new index -> reindex data -> swap alias atomically -> delete old index. Always query via alias.

### Sizing and Sharding

- Single shard for <50GB / <50M documents
- 20-40GB per shard guideline
- Replicas: 1 for dev, 1-2 for production

### Indexing Strategies

| Strategy | Latency | Best for |
|----------|---------|----------|
| Real-time (event-driven) | <1s | Critical freshness |
| Near-real-time (queue + batch) | 1-30s | Most use cases |
| Periodic batch | 5-15 min | Large datasets, analytics |

## PostgreSQL Full-Text Search

```sql
ALTER TABLE products ADD COLUMN search_vector tsvector
  GENERATED ALWAYS AS (
    setweight(to_tsvector('english', coalesce(title, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(description, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(tags, '')), 'C')
  ) STORED;

CREATE INDEX idx_products_search ON products USING GIN(search_vector);
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX idx_products_title_trgm ON products USING GIN(title gin_trgm_ops);

-- Search with ranking and highlighting
SELECT id, title, ts_rank_cd(search_vector, query) AS rank,
  ts_headline('english', description, query, 'StartSel=<mark>, StopSel=</mark>') AS highlight
FROM products, plainto_tsquery('english', $1) query
WHERE search_vector @@ query ORDER BY rank DESC LIMIT 20;
```

Graduate from PG FTS when: >1-5M docs, need sub-20ms autocomplete, need facets, need complex scoring, need multi-language analyzers.

## Frontend Integration

- Debounce 200-300ms, loading/error/zero-results states
- Highlight matched terms with `<mark>`, keyboard navigation in results
- Preserve search state in URL params for shareability
- Components: search input, filter bar/sidebar, result list, facet panels, sort selector, autocomplete dropdown

## Anti-Patterns

- Reindexing by deleting the index -- causes downtime; use alias swapping for zero-downtime reindex
- Exposing raw Elasticsearch DSL to the frontend -- tight coupling, security risk
- No relevance tuning -- default BM25 field weights are rarely optimal for domain-specific content
- Synchronous indexing blocking writes -- decouple with async queue or CDC

## Output Format

```
Technology:    [engine selected]
Index:         [name, document count, shard config]
Fields:        [indexed fields with boost weights]
Relevance:     [boosting, scoring, fuzzy config]
Features:      [autocomplete, facets, synonyms, did-you-mean, multi-language]
Analytics:     [query logging, click tracking, zero-result monitoring]
Indexing:      [strategy, latency, reindex approach]
```

## Done Criteria

- Search returns relevant results within 200ms (p95)
- Handles typos via fuzzy matching
- Results ranked with field boosting and custom scoring
- Index stays in sync with source data
- Search UI has loading, empty, error, and zero-results states
- Autocomplete in <100ms after 2-3 characters
- Faceted search with accurate counts and multi-select
- Synonyms configured for domain terminology
- Zero-result queries tracked and reviewed
- Reindexing with zero downtime (alias swapping)
- Search API rate-limited
