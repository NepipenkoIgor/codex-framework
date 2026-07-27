# Community skill pilots

Candidates and current hold/compare/reject decisions are pinned in `skills/community-pilot.tsv`. Nothing is installed globally or included in the default core. Planned identical benchmark prompts and the conjunctive adoption gate live in `evals/community-skill-benchmarks.json`; that inventory contains no model-run evidence, and a status is not an adoption result.

```bash
bash scripts/community-skill-pilot.sh list
bash scripts/community-skill-pilot.sh verify
bash scripts/community-skill-pilot.sh validate /tmp/community-skill-fixture
bash scripts/community-skill-pilot.sh fetch vercel-react-best-practices /tmp/react-best-practices-pilot
```

Before adoption, run at least five representative positive tasks and three negative routing tasks against the local and candidate skill. Compare correctness findings, regressions, unnecessary edits, verification quality, context cost, and routing precision. Security/auth/data/payment/deployment candidates also require an independent read-only review.

Statuses:

- `compare` / `compare-reference` / `compare-gap`: licensed candidate is eligible for the identical benchmark, but is not adopted.
- `adapted-local`: an expert-review gap hypothesis was implemented as a narrower local skill; this is not evidence that the upstream or local skill won a reproducible benchmark.
- `hold-*`: provenance, license, reproducibility, or safety evidence is incomplete.
- `reject-*`: the audited candidate overlaps, floats runtime content, or loses a local invariant; it remains only as a recorded decision.

## 2026-07-27 provisional expert review

The three licensed candidates below received a read-only expert comparison against the planned case topics. Candidate/local responses, model and effort identity, per-case assertions and scores were not preserved, so these observations are not reproducible benchmark results and cannot support a superiority or adoption claim. They support only the conservative decisions to retain local ownership and avoid automatic installation.

| Candidate | Expert-review observation | Risk observation | Provisional decision |
|---|---|---|---|
| `supabase-core` | Local workflow retained all five; candidate lacked complete SSR-cookie, Storage authority, and webhook contracts | Candidate over-routed generic PostgreSQL tuning and read-only security audit | Reject replacement; mine only compatible RLS, JWT-freshness, and Storage-upsert traps |
| `supabase-postgres` | Candidate added useful syntax but did not beat the local evidence-first workflow on a complete case | Fixed pool formulas, universal index claims, and insufficiently guarded `EXPLAIN ANALYZE` / `ALTER SYSTEM` violate local safety invariants | Reject wholesale reference; selectively revalidate individual ideas |
| `anthropic-frontend-design` | Candidate owned four text-level visual-direction cases that local implementation skills did not | It lacked screenshot-quality proof and included hidden-memory and fixed-aesthetic behavior | Do not install; add the narrower local `frontend-design-direction` skill |

The visual review suggests a workflow gap; it does not prove that one instruction file produces better-looking interfaces. A future benchmark or visual-superiority claim requires preserved same-condition responses, model/effort/tool metadata, per-case scoring, the same rendered fixture, representative viewport screenshots, and blind human or agreed rubric scoring.

When adopted, preserve upstream repository, commit, source path, license, evaluation evidence, owner, review date, and rollback/replacement mapping. Updates are explicit new reviews, never floating pulls from a default branch.
