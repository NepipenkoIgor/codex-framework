---
name: workflow-engine-design
description: Design approval flows, configurable state machines, business rule engines, and user-facing workflow builders.io, Elsa
metadata:
  version: 1.3
  argument-hint: "workflow type (approval/routing/automation), complexity (simple/complex), user-facing builder needed"
---

Design workflow engine for $ARGUMENTS.


## When to Build vs Adopt

| Scenario | Recommendation |
|----------|---------------|
| Simple approval chain (2-3 steps) | Custom state machine |
| Complex multi-step with timers/retries | Temporal.io or Elsa |
| User-configurable workflows | Custom engine + visual builder |
| BPMN compliance required | Camunda or Elsa |
| Long-running (days/weeks) | Temporal.io or durable engine |

## State Machine Definition

```typescript
interface WorkflowDefinition {
  id: string; name: string; version: number; initialState: string;
  states: Record<string, StateDefinition>;
}

interface StateDefinition {
  type: 'initial' | 'intermediate' | 'approval' | 'parallel' | 'timer' | 'final';
  transitions: TransitionDefinition[];
  onEnter?: ActionDefinition[];
  onExit?: ActionDefinition[];
  timeout?: { duration: string; transition: string }; // ISO 8601 duration
  assignee?: { type: 'user' | 'role' | 'group' | 'dynamic'; value: string; escalateAfter?: string };
}

interface TransitionDefinition {
  event: string; target: string;
  guard?: { field: string; operator: string; value: unknown };
  actions?: ActionDefinition[];
}

interface ActionDefinition {
  type: 'send_email' | 'send_notification' | 'call_webhook' | 'update_record' | 'assign_task';
  config: Record<string, unknown>;
}
```

Example: purchase order with amount-based routing (< $10K -> auto-approve, >= $10K -> director approval), 3-day timeout with escalation, rejection notifications.

## Persistence Model

```sql
CREATE TABLE workflow_instances (
  id UUID PRIMARY KEY, definition_id TEXT NOT NULL, definition_version INT NOT NULL,
  current_state TEXT NOT NULL, context JSONB DEFAULT '{}',
  status TEXT DEFAULT 'active', -- active, completed, failed, cancelled, suspended
  started_by UUID NOT NULL, started_at TIMESTAMPTZ DEFAULT now(), completed_at TIMESTAMPTZ,
  parent_instance_id UUID REFERENCES workflow_instances(id), org_id UUID NOT NULL
);

CREATE TABLE workflow_transitions (
  id UUID PRIMARY KEY, instance_id UUID NOT NULL REFERENCES workflow_instances(id),
  from_state TEXT NOT NULL, to_state TEXT NOT NULL, event TEXT NOT NULL,
  performed_by UUID, comment TEXT, context_snapshot JSONB, created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE workflow_tasks (
  id UUID PRIMARY KEY, instance_id UUID NOT NULL REFERENCES workflow_instances(id),
  state TEXT NOT NULL, assignee_user_id UUID, assignee_role TEXT,
  status TEXT DEFAULT 'pending', due_at TIMESTAMPTZ, completed_at TIMESTAMPTZ, completed_by UUID
);
```

## Workflow Engine Core

The engine handles: start (create instance, execute initial onEnter, create task), transition (find matching transition with guard evaluation, check authorization, execute onExit/transition/onEnter actions, update state, record audit, schedule timeout).

Guard evaluation: compare context field values using operators (eq, neq, gt, gte, lt, lte, in).

## Approval Patterns

- **Sequential**: Reviewer 1 -> Reviewer 2 -> Approver (order matters)
- **Parallel (all)**: All reviewers must approve; any rejection rejects whole workflow
- **Parallel (any)**: First approval completes the step
- **Escalation**: Timeout at each level triggers escalation to next

## Temporal.io Integration

Use for long-running workflows. Activities contain side effects, workflow code is deterministic. Signals for external input (approvals). Queries for reading state. Version workflows for backward compatibility.

```typescript
export async function purchaseOrderApproval(input: PurchaseOrderInput): Promise<ApprovalResult> {
  await sendNotification({ template: 'po-submitted', to: input.reviewerEmail });
  const approved = await condition(() => decision !== undefined, '3 days');
  if (!approved) { /* escalate with another condition + timeout */ }
  // Execute result based on decision
}
export const approvalSignal = defineSignal<['approved' | 'rejected']>('approval');
```

## Elsa (.NET) Integration

Use `WorkflowBase` with fluent builder: `StartWith<SetVariable>().Then<SendNotification>().Then<BookmarkActivity>().When("Approved")...When("Rejected")...`

## Compensation (Saga Pattern)

Every side-effecting action must have a compensation action. Compensate in reverse order of execution. Compensations must be idempotent. Log compensation failures for manual intervention.

```
Reserve inventory <-> Release inventory
Charge payment    <-> Refund payment
Create shipment   <-> Cancel shipment
```

If step N fails, compensate steps N-1 through 1 in reverse order.

## Parallel Execution (Fork-Join)

Define branches with join condition: `all` (all must succeed), `any` (first success proceeds), `n-of-m` (threshold). Execute branches with `Promise.allSettled`, evaluate join condition on results.

## Audit Trail

Record every event: workflow started/completed/failed, state entered, transition performed, action executed, task assigned/completed, timeout triggered, escalation, compensation.

API: `GET /api/workflows/:instanceId/history` -> `[{ timestamp, event, fromState, toState, actor, comment }]`

## Workflow Versioning

- Running instances continue on their original definition version
- New instances use latest version
- Never modify a published definition -- create new version
- Keep old versions available for lifetime of running instances

## User-Facing Workflow Builder

For end-user configurable workflows: drag-and-drop steps, visual connections, step configuration panel, graph validation, preview mode with sample data, version history with diff.

## Anti-Patterns

- No timeout handling — approval steps hang forever; blocked instances accumulate silently
- No compensation logic — partial side-effects (payment charged, inventory reserved) leave data permanently inconsistent
- Modifying running workflow definitions — breaks in-flight instances mid-execution; always create a new version
- Synchronous execution in API handlers — long-running workflows block threads and timeout; always dispatch to background

## Output Format

```
Process:           [business process being modeled]
Engine:            [custom / Temporal / Elsa]
States:            [list with types]
Approval Pattern:  [sequential / parallel / conditional]
Timeouts:          [durations and escalation targets]
Compensation:      [compensating actions]
Parallel:          [fork-join config and join condition]
Versioning:        [definition version management]
Audit:             [what is recorded]
Persistence:       [tables and indexes]
```

## Done Criteria

- Definition models complete business process with all states and transitions
- Guard conditions route correctly (e.g., amount-based approval tiers)
- Tasks assigned to correct users/roles
- Timeouts trigger escalation after configured duration
- Compensation reverses completed steps on later failure
- Parallel execution supports all-must-pass and any-can-pass
- Audit trail records every change with actor and timestamp
- Instances survive server restarts
- Running instances use their original definition version
- Concurrent transitions handled safely (optimistic locking)
