---
name: adr-management
description: Create, review, amend, supersede, or reject architecture decision records with repository evidence and implementation traceability. Use when an architectural decision record is the requested deliverable; not for inventing a decision or documenting routine code.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 3.0
  argument-hint: "decision or open question, decision authority/status, alternatives, evidence, affected systems and links"
---

Manage the ADR requested in $ARGUMENTS.

## Establish the decision record

Read repository instructions, ADR index/templates/numbering, related ADRs, current code/configuration, issues/specs and available implementation evidence. Identify whether a decision has actually been made, by whom, and with what status. If authority or outcome is absent, create a proposed record or decision draft; never invent consensus, acceptance, dates, owners, alternatives, evidence or implementation results.

Use an ADR when a durable architectural, data, API, security, deployment or ownership choice has meaningful alternatives and consequences. Keep routine implementation detail in code/docs. Preserve repository format and location rather than imposing a universal template.

## Content and lifecycle

Record the problem and forces, evidence/assumptions, considered options, decision or unresolved choice, consequences and tradeoffs, migration/rollback, operational ownership, verification and links. Separate observed current state from proposals and future work.

Treat accepted ADRs as immutable historical decisions except for minor corrections and added traceability. A changed decision gets a new ADR that explicitly supersedes the old one; update both records and the index so only the replacement is current. Rejected/deprecated records remain discoverable with reasons. An implementation drifting from an ADR is evidence to reconcile—not permission to silently rewrite history.

For version-sensitive choices, preserve installed project pins and cite matching local or official capability evidence. A “latest” release remembered by the author is not durable evidence; record the constraint or resolution method, and treat upgrades as migrations.

## Verification and output

Check identifier uniqueness, status vocabulary, links, conflicting accepted records, supersession in both directions, and alignment among decision, planned migration and actual code. Always include the repository's documentation/lint checks in verification when present; if their commands or results are unavailable, report that explicitly rather than silently omitting them. Report the ADR path/status, evidence used, decisions not yet authorized, superseded links, implementation/verification state and unresolved consequences.
