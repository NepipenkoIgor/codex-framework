---
name: framework-orchestration-audit
description: Audit Codex framework orchestration, role behavior, skill routing, delegation, verification, and human-like senior-engineer quality.
metadata:
  version: 1.0
  argument-hint: "framework area, target maturity level, validation scope"
---

# Framework Orchestration Audit

Use this skill when evaluating whether the framework behaves like a reliable engineering organization rather than a pile of prompts.

## Audit Dimensions

Score each dimension from 1 to 10 and include concrete evidence from framework files, scripts, or generated briefs.

1. Routing correctness
   - Task intent maps to the right role, tier, and execution pattern.
   - Multilingual and mixed-language requests do not fall through to generic builder routes.
   - Strategic framework work routes to `framework-manager` and high or xhigh reasoning.

2. Skill fit
   - Skill sets are small, relevant, and loaded lazily.
   - Domain roles receive the same domain brain whether they build, review, fix, or test.
   - Cross-cutting skills such as security, observability, docs, and process hygiene appear when risk warrants them.

3. Human-like senior engineer behavior
   - The role first understands the repo, task, and constraints.
   - It states tradeoffs and assumptions without over-asking.
   - It protects unrelated user work, verifies changed behavior, and reports residual risk.
   - It knows when to slow down for requirements, contracts, data, security, or release impact.

4. Multi-agent coordination
   - The main session keeps ownership of the critical path.
   - Delegation is bounded, parallelizable, and has clear file or responsibility ownership.
   - Contract-first work creates shared decisions before parallel implementation begins.
   - Handoff state captures blockers, decisions, changed files, and verification.

5. Verification and evaluation
   - Health checks cover structure and routing expectations.
   - Eval tests cover representative task language and expected role/tier/skill outcomes.
   - Quality gates run after framework changes.
   - Failures are actionable rather than only pass/fail.

6. Runtime safety
   - Permission, sandbox, network, and local capability constraints are visible in briefs.
   - Destructive or external actions have explicit approval gates.
   - Tool fallback paths are deterministic.
   - Generated artifacts do not require hidden hooks to work.

## Evidence Checklist

Read only the files needed for the audit:

- `CODEX.md`
- `CODEX.concepts.md`
- `CODEX.skills.md`
- `ORCHESTRATOR_REFERENCE.md`
- `routing.yaml`
- `scripts/codex-fw.sh`
- `scripts/task-brief.sh`
- `scripts/framework-health.sh`
- `scripts/framework-eval.sh` when present
- relevant `agents/*.md`
- relevant `skills/*/SKILL.md`

## Output Format

```md
Status: done | partial | blocked
Scores:
- Routing correctness: N/10
- Skill fit: N/10
- Human-like senior engineer behavior: N/10
- Multi-agent coordination: N/10
- Verification and evaluation: N/10
- Runtime safety: N/10

Strengths:
- ...

Gaps:
- ...

Recommended next changes:
- ...

Validation:
- ...
```

## Done Criteria

- The audit cites concrete framework files or checks.
- At least one executable validation path is run or identified as blocked.
- Recommendations distinguish quick fixes from structural improvements.
