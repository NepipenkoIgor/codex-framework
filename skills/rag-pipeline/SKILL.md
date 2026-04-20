---
name: rag-pipeline
description: Design and implement RAG pipelines — document ingestion, chunking strategies, embedding selection, vector storage, retrieval strategies, reranking, context assembly, and evaluation metrics
metadata:
  version: 1.4
  argument-hint: "document types/sources, embedding model, vector store, retrieval strategy (hybrid/MMR), evaluation dataset size"
---

Design and implement RAG pipeline for $ARGUMENTS.

## Tool Integration

- **Type diagnostics**: run available diagnostics tools after every code change to catch type errors before completion
- docs lookup tools: fetch current library docs before implementing — never rely on training data alone

## Documentation

> Use available docs lookup tools or official docs when you encounter unknown API syntax, current library versions, or framework-specific configuration. Do not rely on training data for library docs — fetch current docs on demand.

## Pipeline Architecture

```
Documents (PDF, HTML, Markdown, etc.)
  |
  v
Ingestion (parse, clean, extract metadata)
  |
  v
Chunking (split into retrieval units)
  |
  v
Embedding (convert chunks to vectors)
  |
  v
Vector Store (index and persist embeddings)
  |
  v
Query Pipeline:
  User Query -> Embed Query -> Retrieve Top-K -> Rerank -> Assemble Context -> LLM Generate -> Response
```

## Document Ingestion

### Parsing by Format

| Format | Parser | Notes |
|--------|--------|-------|
| PDF | pdf-parse, PyMuPDF, Unstructured | Handle tables, images, multi-column |
| HTML | cheerio, BeautifulSoup | Strip nav, footer, ads; keep semantic structure |
| Markdown | remark, markdown-it | Preserve headings as section boundaries |
| DOCX | mammoth, docx | Extract text with heading hierarchy |
| CSV / structured data | Native parsers | Each row or group of rows becomes a chunk |
| Code files | Tree-sitter, AST parsers | Chunk by function/class, preserve context |

### Metadata Extraction

Extract metadata alongside each chunk: `source`, `page`, `title`, `author`, `created_at`, `chunk_index`, `total_chunks`, `heading_hierarchy`. Enables filtered retrieval by date, section, or source.

## Chunking Strategies

### Fixed-Size Chunking

- Split text into chunks of N tokens/characters with overlap
- Simple, predictable, works for homogeneous content
- Typical sizes: 256-1024 tokens with 50-200 token overlap

```typescript
function fixedChunk(text: string, chunkSize: number, overlap: number): string[] {
  const chunks: string[] = [];
  let start = 0;
  while (start < text.length) {
    chunks.push(text.slice(start, start + chunkSize));
    start += chunkSize - overlap;
  }
  return chunks;
}
```

### Recursive Character Splitting

Split by separators (`\n\n` → `\n` → `. ` → ` `) respecting document structure. LangChain `RecursiveCharacterTextSplitter` is the standard implementation.

### Semantic Chunking

- Embed sentences, then split where cosine similarity drops between consecutive sentences
- Produces variable-size chunks aligned to topic boundaries
- More expensive (requires embedding every sentence) but higher retrieval quality

### Contextual Retrieval (Anthropic)

Prepend LLM-generated context summaries (1-2 sentences) to chunks before embedding. Improves retrieval accuracy by 49% with zero query-time cost.

### Parent-Child Chunking (Late Chunking)

- Create small chunks for retrieval (256 tokens) but return the parent chunk (1024 tokens) for context
- Small chunks = precise retrieval; large chunks = better generation context
- Maintain a parent-child mapping: each small chunk links to its parent
- At retrieval: find top-K small chunks, deduplicate by parent, return parent chunks

### Markdown / Heading-Based Chunking

- Split by headings (H1, H2, H3) to preserve section boundaries
- Prepend heading hierarchy to each chunk for context
- Best for documentation, wikis, and structured content

### Chunking Size Trade-Offs

| Size | Use Case |
|------|----------|
| 128-256 tokens | Factoid Q&A, specific lookups |
| 256-512 tokens | General-purpose RAG |
| 512-1024 tokens | Summarization, broad topics |

Default: 512 tokens + 100 token overlap. Increase for more context, decrease if noisy.

## Embedding Models

### Model Selection

| Model | Dimensions | Cost | Quality | Notes |
|-------|-----------|------|---------|-------|
| OpenAI text-embedding-3-small | 1536 | Low | Good | Best cost/quality ratio |
| OpenAI text-embedding-3-large | 3072 | Medium | Excellent | Supports dimension reduction |
| Cohere embed-v3 | 1024 | Medium | Excellent | Multilingual, search-optimized |
| Voyage AI voyage-3 | 1024 | Medium | Excellent | Code and technical content |
| BGE / E5 (local) | 768-1024 | Free (compute) | Good | Privacy, no API dependency |
| Nomic embed-text (local) | 768 | Free (compute) | Good | 8192 token context window |

### Embedding Rules

Same model for docs + queries; normalize to unit length; batch 100-500 per API call; cache by doc hash; use `dimensions` param for cost savings; asymmetric search → asymmetric models

### Dimension Choices

384-512 (fast/simple); 768-1024 (balanced); 1536-3072 (highest quality); use PCA/model-native reduction for large indexes

## Retrieval Strategies

### Similarity Search (k-NN)

- Retrieve top-K chunks by cosine similarity to the query embedding
- Simple, fast, and effective for most use cases
- Default K: 5-10 for generation, 20-50 for reranking pipeline

### Maximum Marginal Relevance (MMR)

- Balance relevance with diversity: avoid returning near-duplicate chunks
- `score = lambda * similarity(query, doc) - (1 - lambda) * max(similarity(doc, selected_docs))`
- Lambda: 0.5 for balanced, 0.7 for more relevance, 0.3 for more diversity
- Use when documents have overlapping content or repeated information

### Hybrid Search (Vector + Keyword) — RECOMMENDED DEFAULT

- Combine dense retrieval (vector similarity) with sparse retrieval (BM25/keyword)
- Reciprocal Rank Fusion (RRF) to merge ranked lists: `score = sum(1 / (k + rank_i))`
- Captures both semantic similarity and exact keyword matches
- Essential when users search for specific terms, product names, or codes
- **Always prefer hybrid over pure vector search** — 10-20% better recall in most benchmarks

```typescript
// Reciprocal Rank Fusion
function rrf(rankings: Map<string, number>[], k: number = 60): Map<string, number> {
  const scores = new Map<string, number>();
  for (const ranking of rankings) {
    for (const [docId, rank] of ranking) {
      scores.set(docId, (scores.get(docId) ?? 0) + 1 / (k + rank));
    }
  }
  return scores;
}
```

### Multi-Query & Self-Query

**Multi-Query**: Generate 3-5 query variations, retrieve, union and deduplicate results. **Self-Query**: LLM extracts filters (date, source, category), apply before vector search. Both improve recall for ambiguous questions.

## Reranking

### Why Rerank

- Initial retrieval (top-100) optimizes for recall with fast approximate search
- Reranking (top-100 -> top-5) optimizes for precision with a more expensive model
- Cross-encoder rerankers consider query-document interaction, not just embedding similarity

### Reranker Options

| Reranker | Type | Latency | Quality |
|----------|------|---------|---------|
| Cohere Rerank | API | ~200ms | Excellent |
| Jina Reranker | API | ~150ms | Good |
| Cross-encoder (local) | Model | ~500ms | Excellent |
| LLM-based rerank | API | ~1-2s | Very good |
| Reciprocal Rank Fusion | Algorithm | <10ms | Good (for merging) |

### Reranking Pipeline

```
User Query
  |
  v
Initial Retrieval: top-50 by vector similarity
  |
  v
Reranker: score each (query, chunk) pair
  |
  v
Select top-5 by reranker score
  |
  v
Context Assembly -> LLM Generation
```

Rules: Retrieve 3-10x chunks, rerank down; API rerankers add 100-500ms, local 500ms+; skip for cost-sensitive (use larger K + MMR); always rerank for precision (legal/medical/enterprise)

## Context Assembly

### Context Window Budgeting

```
Total context window (e.g., 128K tokens)
  - System prompt:       ~500 tokens
  - Conversation history: ~2000 tokens (last 5-10 turns)
  - Retrieved context:   ~4000-8000 tokens (5-10 chunks)
  - Generation headroom: ~2000 tokens (for the answer)
  = Reserve:             remaining tokens as buffer
```

Rules: Leave 20% headroom for generation; prioritize relevant chunks first; include citations; separate chunks with clear delimiters

### Context Formatting & Prompt

Format chunks as `[Source N: filename - section]\n{content}`, separated by `---`. System prompt: answer only from context, cite sources [Source N], say when insufficient, no hallucination.

## Evaluation

### Key Metrics

**Retrieval**: Recall@K >0.8, MRR >0.5, NDCG@K >0.7, Hit Rate >0.9. **Generation**: Faithfulness >0.85, Answer Relevance >0.80, Context Precision >0.75, Context Recall >0.80. Use RAGAS for automated scoring.

### Evaluation Dataset & Tools

Build 50-100 question-answer-context triples (easy, hard, unanswerable). Use RAGAS, DeepEval, LangSmith, or LLM-as-judge for automated evaluation on every pipeline change.

## Framework Integration

### LangChain

- `RecursiveCharacterTextSplitter` for chunking
- `OpenAIEmbeddings` / `CohereEmbeddings` for embedding
- `Chroma` / `Pinecone` / `PGVector` as vector store
- `RetrievalQA` chain or `create_retrieval_chain` for end-to-end
- Use `MultiQueryRetriever` for query expansion
- Use `ContextualCompressionRetriever` with a reranker

### LlamaIndex

- `SimpleDirectoryReader` for document loading
- `SentenceSplitter` / `SemanticSplitterNodeParser` for chunking
- `VectorStoreIndex` for retrieval
- `SubQuestionQueryEngine` for complex multi-part questions
- Built-in evaluation module for retrieval and generation quality

### Vercel AI SDK

- `embed` and `embedMany` for embedding
- `generateText` with tool calls for retrieval
- `streamText` for streaming RAG responses
- Integrate with any vector store via custom retrieval tool

### Custom Implementation

```typescript
// Minimal RAG pipeline
async function ragQuery(query: string): Promise<{ answer: string; sources: string[] }> {
  // 1. Embed query
  const queryEmbedding = await embed(query);

  // 2. Retrieve
  const chunks = await vectorStore.similaritySearch(queryEmbedding, { topK: 20 });

  // 3. Rerank
  const reranked = await reranker.rerank(query, chunks, { topN: 5 });

  // 4. Assemble context
  const context = assembleContext(reranked);

  // 5. Generate
  const answer = await llm.generate({
    system: RAG_SYSTEM_PROMPT,
    user: `Context:\n${context}\n\nQuestion: ${query}`,
  });

  return {
    answer: answer.text,
    sources: reranked.map(c => c.metadata.source),
  };
}
```

## Indexing Pipeline

### Incremental Indexing

- Track document hashes: re-embed only when content changes
- Delete stale embeddings when source documents are removed
- Use a document registry (database table) mapping `source -> chunk IDs -> embedding IDs`
- Run indexing as a background job, not in the request path

### Pipeline Steps

```
1. Detect new/changed/deleted documents (hash comparison)
2. Parse changed documents (extract text and metadata)
3. Chunk parsed text (apply chunking strategy)
4. Embed chunks (batch API calls)
5. Upsert embeddings to vector store (with metadata)
6. Delete embeddings for removed documents
7. Update document registry with new hashes and chunk IDs
```

## Anti-Patterns

- Different embedding models for docs + queries → meaningless similarity scores
- Filling entire context window → no generation room, degraded quality
- Vector-only retrieval (no reranking) → noisy results
- No evaluation → can't track improvements/regressions
- Ignoring document structure during chunking → broken semantic boundaries

## Implementation Workflow

1. Identify document sources, formats, and update frequency
2. Choose chunking strategy based on content structure (recursive for general, heading-based for docs)
3. Select embedding model based on quality, cost, and privacy requirements
4. Set up vector store with appropriate index type and distance metric
5. Implement retrieval pipeline: embed query -> retrieve top-K -> rerank -> assemble context
6. Design the generation prompt with grounding instructions and citation format
7. Build evaluation dataset with question-answer-context triples
8. Measure retrieval metrics (recall, MRR) and generation metrics (faithfulness, relevance)
9. Tune chunk size, top-K, reranker threshold based on evaluation results
10. Set up incremental indexing for document updates

## Output Format

For each RAG pipeline implementation:

```
Pipeline:          [end-to-end / retrieval-only / indexing-only]
Documents:         [formats and sources]
Chunking:          [strategy, size, overlap]
Embedding:         [model, dimensions]
Vector Store:      [provider, index type, distance metric]
Retrieval:         [similarity / MMR / hybrid, top-K]
Reranking:         [reranker model, top-N after rerank]
Context Budget:    [tokens allocated for context vs generation]
Evaluation:        [metrics tracked and current scores]
```

## Done Criteria

- Documents are parsed, chunked, and embedded with metadata
- Retrieval returns relevant chunks for representative queries (recall@10 > 0.8)
- Reranking improves precision over raw retrieval (measurable improvement)
- Generated answers are grounded in context (faithfulness > 0.85 by LLM-as-judge)
- Unanswerable questions are handled explicitly (no hallucination)
- Citations reference the correct source documents
- Incremental indexing updates only changed documents
- Evaluation dataset exists with 50+ queries and runs on pipeline changes
- Context window budget is respected (no truncation, generation headroom preserved)
