---
name: runbook-generation
description: Create concise operational runbooks for incidents, deploys, manual recovery, and support workflows.
---

# Runbook Generation

Use this skill when the deliverable is an operational runbook or on-call procedure.

## Workflow

1. State trigger conditions clearly.
2. List the exact checks and commands in order.
3. Include rollback, escalation, and success criteria.
4. Keep the runbook executable under pressure.

## Repo Context

- Reuse existing incident, deploy, support, and on-call templates before creating a new format.
- Prefer project-native commands, dashboards, logs, and runbook links over generic examples.
- Call out environment assumptions such as staging, production, region, tenant, feature flag, and required permissions.

## Constraints

- Do not include secrets, credentials, customer PII, or destructive commands without an explicit approval gate.
- Do not invent monitoring names, owners, dashboards, or rollback commands; mark unknowns as gaps.
- Keep emergency steps short, ordered, and safe to execute by someone who is tired.

## Verification

- Confirm every command exists or label it as a placeholder.
- Check that rollback and success criteria are observable.
- Include one dry-run or low-risk validation path when the repo supports it.

## Output Contract

- Trigger:
- Scope:
- Preconditions:
- Steps:
- Rollback:
- Escalation:
- Success criteria:
- Open gaps:
