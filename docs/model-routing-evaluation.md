# Native model and effort evaluation

This document defines an experimental candidate policy. It does not override a user's root-model choice, configure a project default, pin ordinary profiles, or implement a router. Codex remains responsible for model selection and subagent lifecycle. A parent may request a supported model and reasoning effort only on a fresh or bounded-history native spawn; full-history spawns inherit the parent.

## Candidate classes

| Bounded work | Candidate | Effort |
| --- | --- | --- |
| Mechanical, clear, repetitive or high-volume | `gpt-5.6-luna` | low or medium |
| Read-heavy exploration and inventory | `gpt-5.6-terra` | low or medium |
| Multi-step implementation, testing and blocker diagnosis | `gpt-5.6-sol` | medium or high |
| Architecture and independent high-risk falsification | `gpt-6-astra` | high, xhigh or max |

Credentials, missing authority, provider outages and live waits remain at their responsible boundary and never trigger model escalation. An unsupported combination or missing effective child metadata is `unverifiable`; there is no fallback ladder. Change model or effort only for a stated ambiguity, capability or risk reason, and preserve every correctness, security and delivery gate.

## Capability pilot

Before comparative evaluation, run one disposable fresh spawn for each candidate. Record requested and effective model and effort, topology, parent model and effort, tool availability, completion status and complete task-family usage. Reject the experiment if effective metadata is absent, inheritance differs from the declared topology, or a requested combination is unsupported.

The 2026-09-21 native Desktop pilot used four no-tool, no-history canaries. Each emitted the exact sentinel and each recorded one matching `turn_context`:

| Requested / effective | Session | Input / cached / output |
| --- | --- | --- |
| `gpt-5.6-luna / low` | `01a0c302-7b1c-76a1-9fd7-e0d1358d0e00` | 31,053 / 18,176 / 10 |
| `gpt-5.6-terra / low` | `01a0c302-8a96-7480-9228-5a4aa75bbd8d` | 32,590 / 14,080 / 10 |
| `gpt-5.6-sol / medium` | `01a0c302-985d-7922-83e6-44f5bc6b258d` | 32,587 / 19,840 / 9 |
| `gpt-6-astra / high` | `01a0c302-bb14-7cf3-83cb-1d6f376a07f3` | 36,810 / 19,968 / 10 |

This proves native availability and effective metadata on the sampled Desktop runtime only. The large one-response input also shows why unnecessary agents can cost more than a cheaper model saves. It does not prove comparative quality, a 25% reduction, CLI-surface parity, or permission to activate routing.

## Paired protocol

Compare baseline Sol/medium inheritance with the candidate policy on twelve fixed tasks: three mechanical, three read-heavy, three implementation and three high-risk tasks. Pin request, source, tools, environment and ground truth. Run three sequential pairs per task with concurrency one and alternating `AB`/`BA` order from fresh task state.

The primary metric is complete-family input plus output tokens; reasoning is reported as an output subset and is never added twice. Secondary metrics are cached and uncached input, active wall time, external wait time, correction turns and rework. Include failures and report results and dispersion per class.

Quality is a hard gate: every known security and correctness assertion must pass, no new high-severity ground-truth defect may be missed, and every baseline-passed user path must still pass. For Luna/Terra-eligible classes, a 25% primary-metric reduction is a candidate target, not a claim of monetary or account-credit savings. For high-risk work, Astra must reduce correction turns or detect seeded defects no worse than baseline. Three repetitions provide bounded experimental evidence, never a universal guarantee.

Only a separately challenged change may promote passing candidate guidance into installed global instructions. Failed or inconclusive classes continue to inherit the user's native selection.
