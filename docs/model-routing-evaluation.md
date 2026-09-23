# Native model and effort evaluation

This is a candidate policy for bounded native subagents, not a model router or a root-model override. The user-selected root model remains authoritative. Full-history spawns inherit the parent model and effort; an explicit override requires a fresh or bounded-history spawn and verified effective metadata. Unsupported combinations stop that lane without a silent fallback.

## Candidate classes

Classify the task from its known risk and ambiguity before spawning. A risk-related noun alone does not select Astra: reading an applied migration list is inventory, while designing a cross-service migration with rollback is a high-risk decision.

| Bounded work | Candidate model / effort | Escalation evidence |
| --- | --- | --- |
| Exact inventory or predetermined command/readback with machine-checkable result | `gpt-6-luna / low` | Broader but consistent context → Luna/medium; conflicting evidence → Sol/medium |
| Coordinated, non-conflicting multi-file or multi-object reading from clear criteria | `gpt-6-luna / medium` | Contradictory sources or judgment → Sol/medium |
| Ordinary implementation, orchestration, evidence reconciliation or provider-state judgment | `gpt-6-sol / medium` | Multiple plausible root causes or cross-service diagnosis → Sol/high |
| Ambiguous debugging or integration with competing hypotheses | `gpt-6-sol / high` | Material cross-boundary and high-consequence decision → Astra/high |
| Ambiguous architecture, auth, schema, migration, concurrency, data integrity or deployment decision with material consequence | `gpt-6-astra / high` | A separately authorized high-risk review may test Astra/xhigh |

The long-lived Property-style root normally remains at the user's selected setting; a `Sol/medium` root is a candidate, not an installed default. Escalate with one bounded child carrying the minimum evidence bundle, then return to the unchanged root. Do not repeatedly reconfigure a large root context. The current reviewer profile is proven at `high`; `Astra/xhigh` is a capability-pilot candidate, not an installed reviewer setting. `max` is not a ladder rung or a second independent review. It requires a specific unresolved high-severity question and new evidence or a materially revised question.

No profile defaults to `none`. Consider it only for a no-tool or single deterministic operation with machine-verifiable output and no interpretation. Waiting, missing credentials or authority, provider outages, elapsed time, raw volume and tool errors never justify higher effort. A retry at higher effort on unchanged evidence is invalid. The smallest capable native tool executes exact checks; agents must not ask the user to run commands that their authorized tool can execute. Tool receipts and provider readback, rather than agent prose, establish completion.

## Capability and quality gate

Before promotion, run a disposable native spawn for every requested model/effort/topology. Record requested and effective profile, model and effort, parent configuration, tool availability, completion status and complete-family usage. Reject a combination when effective metadata is absent, the native surface rejects it, or the result silently inherits a different setting. Availability on one Desktop runtime does not establish CLI parity or availability in another workspace.

The 2026-09-21 Desktop pilot sampled four older no-tool canaries, one response each: `gpt-5.6-luna/low`, `gpt-5.6-terra/low`, `gpt-5.6-sol/medium`, and `gpt-6-astra/high`. Their input totals were 31,053, 32,590, 32,587 and 36,810 tokens respectively; the recorded cached inputs were 18,176, 14,080, 19,840 and 19,968. This proves only sampled availability and significant per-child startup cost. It does not establish GPT-6 Luna/Sol availability, comparative quality, cost reduction, CLI parity or permission to promote this candidate policy.

The 2026-09-23 Desktop no-history capability pilot returned the exact sentinel and matching native `turn_context` for five candidate pairs:

| Model / effort | Session | Input / cached / output tokens |
| --- | --- | --- |
| Luna/low | `01a0caff-ab91-7243-8b7c-f6aed9c3ae94` | 36,246 / 14,080 / 12 |
| Luna/medium | `01a0cb00-567c-7ea0-af8e-a06097e3d765` | 36,247 / 14,080 / 13 |
| Sol/medium | `01a0cb00-6710-7b33-ade6-6c6647878168` | 36,423 / 0 / 11 |
| Sol/high | `01a0caff-b6c6-7953-8d90-44187cdcc04e` | 36,422 / 20,096 / 19 |
| Astra/high | `01a0caff-c241-7391-a266-1d9960cf8451` | 36,874 / 14,080 / 11 |

The pilot verifies only these exact pairs on this Desktop account and topology. The 36K-input startup per child strengthens the requirement to delegate only bounded work with expected value above context cost. No `Astra/xhigh`, `max`, `none`, or CLI-surface pair was certified.

For the Property pilot, screen four fixed task families once each: board/ownership reconciliation, ordinary implementation, migration/concurrency review, and cross-agent ownership conflict. Include contradictory GitHub/board/deploy evidence, a missing-auth or provider-outage boundary, a merged PR with pending CI, and an executable check. Pin request, source, tools, environment, ground truth and delivery criteria. For each family, compare the native GPT-5.6 Sol baseline with GPT-6 candidates, then run three sequential baseline/best-candidate pairs in alternating order from fresh state. Reject unsupported pairs before the quality comparison. This is a task-family pilot, not proof of a universal model policy.

Quality is a hard gate: every known security/correctness assertion and previously passing user path must remain correct; no new high-severity defect or unsupported delivery claim may appear. Measure complete-family input and output tokens, with cached input as an input subset and reasoning as an output subset, plus active wall time, provider wait time, correction turns, tool calls, repeated reads and rework. Do not infer account spending or savings from token counts alone. A 25% token reduction in routine classes is an experiment target, not a release claim; high-risk candidates must improve defect detection or correction turns without weakening the quality gate. Three repetitions give bounded evidence, not a universal guarantee.

Promote only a task family with supported effective metadata, unchanged quality and repeatable complete-family results in a separately challenged change. Failed or inconclusive classes continue to inherit the user's native selection. The target is zero ownership, goal-status and unjustified GitHub-Browser violations and at least 50% fewer responses/tool calls without skipping required checks; it remains an observed target, not an assumed saving. No shell router, fallback ladder, cache wrapper or automatic root-model pin is introduced.
