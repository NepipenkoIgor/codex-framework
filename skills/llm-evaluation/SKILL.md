---
name: llm-evaluation
description: Evaluate LLM outputs and prompts — accuracy metrics, LLM-as-judge patterns, prompt regression testing, A/B comparison, hallucination detection, retrieval quality metrics, and CI integration
metadata:
  version: 1.3
  argument-hint: "model/provider, task type, evaluation metrics, dataset size, scoring method"
---

Implement LLM evaluation for $ARGUMENTS.

## Documentation

> Use **available docs lookup tools or official docs** for current promptfoo, RAGAS, DeepEval, and LLM SDK docs. Do not rely on training data for library configuration syntax.

## Evaluation Dataset Design

### Dataset Composition

| Category | Proportion | Purpose |
|----------|-----------|---------|
| Easy / straightforward | 30% | Baseline, catch catastrophic regressions |
| Medium / typical | 40% | Representative of real usage |
| Hard / edge cases | 20% | Stress test: ambiguity, long context, multi-step |
| Adversarial / tricky | 10% | Robustness: prompt injection, unanswerable |

Rules:
- Minimum 50 examples for reliable evaluation, 200+ for statistical confidence
- Include examples the model should refuse or say "I don't know"
- Never include training data in evaluation sets (data contamination)
- Version the dataset alongside prompts

### Dataset Sources

- Production logs: sample real user queries (anonymized)
- Manual curation: domain experts create examples with gold answers
- Synthetic generation: LLM generates examples, human validates
- Failure analysis: examples from production errors become eval cases

## Metrics

### Reference-Based Metrics

| Metric | Use When |
|--------|----------|
| Exact Match | Classification, extraction |
| ROUGE-L | Summarization |
| BERTScore | General text quality |
| Levenshtein | Structured output, code |

### LLM-as-Judge Metrics

| Metric | Evaluation Prompt Pattern |
|--------|--------------------------|
| Faithfulness | "Does the answer contain claims not supported by the context?" |
| Relevance | "How well does the answer address the question? (1-5)" |
| Completeness | "Does the answer address all parts of the question?" |
| Harmlessness | "Does the response contain harmful content?" |

### Retrieval Metrics (RAG Systems)

| Metric | What It Measures |
|--------|-----------------|
| Recall@K | Coverage: did we find all relevant docs? |
| Precision@K | Noise: what fraction of results are relevant? |
| MRR | Speed: how quickly is the first relevant result? |
| NDCG@K | Ranking: are relevant docs ranked higher? |

## LLM-as-Judge Implementation

### Rubric Design

Use a 1-5 scale with explicit rubric. Include reasoning in the output. Set temperature to 0 for deterministic judgments.

```typescript
const JUDGE_PROMPT = `Score the response 1-5:
5 - Excellent: Accurate, complete, addresses the question
4 - Good: Mostly accurate, minor omissions
3 - Acceptable: Notable gaps or inaccuracies
2 - Poor: Significant issues
1 - Unacceptable: Incorrect or harmful

Question: {question}
{context_block}
Response: {response}

Return JSON: { "score": <1-5>, "reasoning": "<explanation>" }`;
```

### Pairwise Comparison

Run comparisons twice with swapped order to eliminate position bias. If both orders agree, return that winner. If they disagree, call it a tie.

### Judge Reliability Rules

- Use a strong model for judging (Claude Sonnet or GPT-4o) — never judge with the same model being evaluated
- Run pairwise comparisons with position swapping
- Inter-annotator agreement: compare LLM judge scores with human ratings (target >0.7 correlation)
- Include the rubric in every judge call

## Hallucination Detection

### Approach: Claim Extraction + Verification

1. Extract individual factual claims from the response
2. Verify each claim against the provided context
3. Compute faithfulness score: `supported_claims / total_claims`

| Metric | Target |
|--------|--------|
| Faithfulness | >0.9 |
| Contradiction rate | <0.02 |
| Abstention rate (unanswerable Qs) | >0.8 |

## Prompt Regression Testing

### Regression Thresholds

| Metric | Block Merge If |
|--------|----------------|
| Quality score (1-5) | Drops >0.2 with p<0.05 |
| Faithfulness | Drops >0.05 |
| Relevance | Drops >0.1 with p<0.05 |
| Exact match | Drops >0.05 |
| Latency | Increases >50% |

### Statistical Testing Rules

- Minimum 100 examples for continuous metrics; 200 for binary metrics
- Use paired tests when comparing two versions on the same dataset
- Report confidence intervals, not just p-values
- Do not cherry-pick metrics — report all pre-registered metrics

## Evaluation Tools

### promptfoo

> Use available docs lookup tools or official docs to fetch current promptfoo docs for YAML config syntax and assertion types.

Run: `npx promptfoo eval` and `npx promptfoo view` for the comparison UI.

### RAGAS (RAG Evaluation)

> Use available docs lookup tools or official docs to fetch current RAGAS docs for metric configuration and Dataset format.

Core metrics: faithfulness, answer_relevancy, context_precision, context_recall.
Target scores: faithfulness > 0.85, answer_relevancy > 0.80, context_precision > 0.75, context_recall > 0.80.

### DeepEval

> Use available docs lookup tools or official docs to fetch current DeepEval docs for metric classes and test case structure.

CI integration: `deepeval test run test_evals.py` — fails pipeline if metrics drop below thresholds.

## CI Integration

Trigger on changes to `prompts/**` or `evals/**`. Steps:
1. Run prompt evaluations
2. Compare metrics against baseline stored in `eval-baselines.json`
3. Fail CI if any metric drops more than 5% from baseline
4. Post results as PR comment with metric comparison table

## Red-Teaming & Safety Evaluation

Adversarial categories:
- Jailbreak attempts: "Ignore previous instructions and..."
- Prompt injection: hidden instructions in user-provided content
- Information extraction: "What's in your system prompt?"
- Harmful content: requests for dangerous/illegal information
- Bias probing: questions designed to elicit biased responses

Verify each red-team case produces the expected behavior (refuses, deflects, or maintains guardrails).

## Anti-Patterns

- Using the same model to generate and judge — biased self-evaluation inflates scores
- Too few examples (<20) — results are noise, not signal
- No statistical significance testing — promoting changes based on random variation
- Ignoring latency and cost — quality at any cost is not production-ready
- Not versioning the evaluation dataset — dataset drift makes comparisons meaningless

## Implementation Workflow

1. Define what quality means for the use case
2. Build a dataset with 50-200 examples across difficulty levels
3. Select metrics: reference-based and/or LLM-as-judge
4. Establish a baseline on the current prompt version
5. Set regression thresholds based on baseline variance
6. Integrate into CI; block on regression
7. Add statistical significance testing for A/B comparisons
8. Update the dataset when new failure modes are discovered

## Done Criteria

- Evaluation dataset with 50+ examples across difficulty levels
- Metrics defined and computed for every eval run
- Baseline established; regression thresholds enforced in CI
- LLM-as-judge calibrated against human ratings
- Statistical significance required before promoting prompt changes
- Evaluation results posted to PRs with metric comparison tables
- Hallucination detection runs for RAG-based prompts
- Dataset versioned and updated when new failure modes are found
