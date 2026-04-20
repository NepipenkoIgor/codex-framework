---
name: incident-response
description: Handle production incidents with rapid diagnosis, mitigation, and post-mortem
metadata:
  version: 1.2
  argument-hint: "incident description, severity (SEV1/2/3), affected service, symptoms observed"
---

Handle $ARGUMENTS.


## Example

Deployment-caused API outage -- diagnosis and mitigation:

```
Incident: 500 errors spiking on /api/orders after deploy at 14:32 UTC

1. Triage (14:35):
   $ git log --oneline -5 --since="4 hours ago"
   a1b2c3d feat: add inventory check to order service
   → Deploy at 14:32 correlates with error onset.

2. Diagnose (14:38):
   $ kubectl logs deploy/order-service --since=10m | grep ERROR | head -20
   ERROR: column "inventory_status" does not exist
   → New code references a column from a migration that hasn't run in production.

3. Mitigate (14:40):
   $ kubectl rollout undo deployment/order-service
   deployment.apps/order-service rolled back

4. Verify (14:42):
   $ curl -s https://api.example.com/api/orders | jq '.status'
   "ok"
   → Error rate returned to baseline within 2 minutes.

5. Follow-up:
   - Run the pending migration, then redeploy.
   - Add CI check: fail deploy if pending migrations exist.
```

Implementation workflow:

1. Read the incident description and classify severity
2. Identify the most likely incident pattern from symptoms
3. Propose diagnosis steps to confirm root cause
4. Recommend mitigation in priority order (rollback > flag > scale > hotfix > full fix)
5. Provide specific commands and code changes for mitigation
6. Define verification checks to confirm resolution
7. Generate communication templates for stakeholders
8. Create post-mortem template with timeline and action items
9. Recommend monitoring improvements and runbook updates

Output format:

```
Incident Response Plan
-----------------------
Severity: SEV-N
Category: <deployment | database | infrastructure | traffic | data>
Estimated blast radius: <affected services, users, regions>

Diagnosis Steps:
1. <check with specific command>
2. <check with specific command>
3. <check with specific command>

Recommended Mitigation:
Priority 1: <fastest safe fix with commands>
Priority 2: <alternative if priority 1 fails>

Verification:
1. <metric to watch and expected behavior>
2. <command to confirm resolution>

Communication:
<status update template filled in>

Follow-up:
- <action item 1>
- <action item 2>
```

## Output Format

Classify severity first. Recommend fastest safe mitigation, not most thorough fix. Provide specific, executable commands. Include rollback procedures. Define clear verification criteria.

## Done Criteria

- Root cause identified and documented
- Mitigation applied and verified
- Communication sent to stakeholders
- Post-mortem scheduled (SEV1/2)
- Runbook updated or created

## Anti-patterns

- Recommending overly complex multi-step fixes when rollback would resolve faster
- Skipping verification steps before declaring resolution
- Assuming cause without sufficient diagnosis
- Post-mortem generation without clear action items
- Ignoring monitoring gaps that allowed incident escalation
