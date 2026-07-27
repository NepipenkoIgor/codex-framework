---
name: rag-pipeline
description: Design and implement retrieval-augmented generation pipelines with authorized ingestion and retrieval, provenance, lifecycle handling, empirical tuning, and evaluation. Use when retrieval is a primary part of the requested system; use prompt-engineering for prompt-only work and llm-evaluation for evaluation-only work.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.0
  argument-hint: "corpus, tenants and authorization model, retrieval use cases, stores/providers, quality/latency/cost constraints"
---

Design or implement the RAG pipeline requested in $ARGUMENTS.

## Establish the local contract

1. Read repository instructions, manifests, lockfiles, schemas, ingestion and query paths, authorization boundaries, stores, tests, and deployment constraints.
2. For an existing project, preserve installed versions and verify capabilities from generated types, CLI help, configuration schema, or matching official documentation. Check applicable runtime engine constraints, dependency peers, compiler/framework, embedding/vector-store adapters, test runner and deployment runtime together. Treat upgrades and embedding migrations as separate work.
3. For greenfield work, generate ephemeral stack context with `scripts/framework-stack-context.py`; resolve supported stable frameworks and production LTS runtimes from official distribution channels, then make the generated manifest and lockfile authoritative.
4. Define source ownership, tenant/resource identity, freshness and deletion policy, answer contract, availability target, and quality/latency/cost budgets before choosing components. Before any deletion, index cutover, or other material mutation, resolve the exact source/index/cache/backup targets, acting deletion authority and permissions, accountable policy/operations owner, and a recovery plan with reconciliation/forward-fix or rollback targets and SLO; unresolved authority or recovery blocks the mutation.

Do not select a provider, embedding model, chunk size, overlap, retrieval depth, fusion method, reranker, score threshold, or context budget from a universal recipe. Compare candidates on representative corpus and query slices within the actual operating constraints.

## Security and data lifecycle

- Authorize the actor, tenant, source, and resource at both ingestion and query time. Derive namespaces and access filters from trusted server state, never solely from client-supplied metadata or model output.
- Treat documents, metadata, queries, retrieved chunks, and tool output as untrusted data. Delimit them from instructions; retrieved text cannot grant authority or override system policy.
- Complete quarantine classification before production ingestion. Malformed, suspicious, or poisoned content must not enter or remain retrievable from any serving index merely because its source is otherwise authorized; keep quarantine and production indexes separate, record the disposition, and abstain while safety is unresolved.
- Apply retention, regional, PII, secret, and audit policy to raw documents, parsed artifacts, embeddings, logs, caches, eval data, and backups.
- Represent deletion with a durable source version or tombstone and propagate it through chunks, indexes, caches, derived answers, and rebuilds. Verify that deleted or unauthorized content cannot be returned; document backup erasure behavior rather than implying instant deletion.
- Bound parsing, fan-out, retries, timeouts, token use, and provider calls. Derive retry attempts or elapsed-time ceilings from the operation deadline/SLO, provider limits, idempotency and ambiguity window, queue visibility/lease, downstream capacity, and observed recovery behavior; if those inputs are unavailable, keep retries disabled or block enablement rather than inventing a number. Make ingestion idempotent and resumable; distinguish poison records from transient failures.

## Provenance and index compatibility

Each served chunk must retain enough provenance to reproduce and revoke it: tenant/resource identity, source and source version, chunk/span or page, parser/schema version, ingestion run, embedding model/version/dimensions, index namespace, and timestamps. Citations shown to users must resolve to authorized source material.

Never mix vectors whose models, dimensions, normalization, distance semantics, or source schemas are incompatible. For embedding or schema migration:

1. create a versioned namespace or index;
2. reprocess from authoritative sources with resumable checkpoints;
3. validate counts, authorization filters, deletions, retrieval quality, latency, and cost;
4. dual-read or shadow only when result comparability is defined;
5. cut over atomically with a rollback pointer;
6. retire the old index according to retention policy.

## Retrieval and answer design

- Preserve meaningful document structure and stable source spans. Evaluate fixed, recursive, semantic, or parent-child chunking instead of declaring one default.
- Establish a simple baseline, then evaluate dense, sparse, hybrid, metadata-filtered, query expansion, diversity, and reranking only where slices show benefit. Tune candidate depth and final context size together.
- Deduplicate and diversify context where appropriate, enforce a token budget, and keep citation/source identity attached during assembly.
- Require the answer layer to separate supported facts from inference, cite evidence, and abstain or request clarification when authorized evidence is insufficient.
- Schema-valid model output is not authorization or permission for a downstream action. Server code validates identity, policy, targets, and side effects.

## Evaluation and verification

Build representative, versioned test sets from approved production samples, domain-expert cases, and reviewed synthetic cases. Include tenant and permission boundaries, languages, document types and lengths, rare queries, ambiguity, unanswerable questions, fresh/updated/deleted sources, poison and injection attempts, and provider failure modes.

Persist malformed, suspicious and poisoned fixtures through the real quarantine path, then query every production serving index/cache/API and prove the fixtures are absent while their protected quarantine records and dispositions remain auditable. Merely listing poison cases or checking classifier output is not serving-index isolation evidence.

Measure retrieval coverage/ranking and answer groundedness/citation correctness alongside authorization leakage, abstention, latency distributions, cost, availability, and index freshness. Choose metrics, cutoffs, sample sizes, and promotion criteria from the use case, harm model, baseline variance, and decision risk; report aggregate and slice results. Re-run affected tests after fixes and monitor drift by prompt, model, embedding, corpus, parser, and index version.

## Output contract

Report:

- repository and version evidence;
- data flow, trust and authorization boundaries;
- provenance, deletion, migration, rollback, and failure behavior;
- empirical choices and rejected alternatives;
- implementation changes or a concrete design;
- focused and affected checks with actual results;
- slice-level quality, safety, latency, and cost evidence;
- unresolved provider, policy, or production-validation risks.

Do not claim completion from configuration, indexing success, or aggregate quality alone.
