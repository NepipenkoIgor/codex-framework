---
name: n8n-test
description: Test n8n workflows — unit test code nodes with Vitest/Jest, mock HTTP nodes, validate webhook flows, integration test via n8n API, and verify workflow JSON structure
metadata:
  version: 1.1
  argument-hint: "workflow nodes to test, test framework (Vitest/Jest), API endpoints to mock"
---

Test $ARGUMENTS for n8n workflow reliability.


## Level 1: Code Node Unit Tests

Extract business logic from code nodes into testable functions.

### Pattern: Extract and Test

```typescript
// workflow-utils/transform-order.ts — extracted from Code node
export function transformOrder(input: { customerName: string; items: any[]; total: number }) {
  return {
    customer: input.customerName.trim(),
    lineItems: input.items.map(i => ({ sku: i.sku, qty: i.quantity, price: i.unitPrice })),
    totalCents: Math.round(input.total * 100),
    currency: 'USD',
  };
}

// workflow-utils/transform-order.test.ts
import { describe, it, expect } from 'vitest';
import { transformOrder } from './transform-order';

describe('transformOrder', () => {
  it('converts total to cents', () => {
    const result = transformOrder({ customerName: 'John', items: [], total: 99.99 });
    expect(result.totalCents).toBe(9999);
  });

  it('trims customer name', () => {
    const result = transformOrder({ customerName: '  Jane  ', items: [], total: 0 });
    expect(result.customer).toBe('Jane');
  });

  it('maps items to line items', () => {
    const items = [{ sku: 'ABC', quantity: 2, unitPrice: 10 }];
    const result = transformOrder({ customerName: 'X', items, total: 20 });
    expect(result.lineItems).toEqual([{ sku: 'ABC', qty: 2, price: 10 }]);
  });
});
```

### What to Extract and Test
- Data transformations (mapping, filtering, formatting)
- Validation logic (input checks, business rules)
- Conditional routing decisions (if/switch logic)
- Error classification (retry vs skip vs fail)
- Rate calculations, date math, string parsing

## Level 2: HTTP / API Node Mocking

### Mock External APIs with nock or msw

```typescript
import nock from 'nock';
import { processWebhookPayload } from './webhook-handler';

describe('Stripe webhook handler', () => {
  beforeEach(() => {
    // Mock the downstream API the workflow calls
    nock('https://api.internal.com')
      .post('/orders')
      .reply(201, { id: 'order-123', status: 'created' });
  });

  afterEach(() => nock.cleanAll());

  it('creates order from checkout.session.completed', async () => {
    const payload = { type: 'checkout.session.completed', data: { object: { id: 'cs_123', amount_total: 5000 } } };
    const result = await processWebhookPayload(payload);
    expect(result.orderId).toBe('order-123');
  });

  it('skips non-checkout events', async () => {
    const payload = { type: 'payment_intent.created', data: { object: {} } };
    const result = await processWebhookPayload(payload);
    expect(result).toBeNull();
  });
});
```

### AI Step Mocking

```typescript
// Mock LLM responses for AI nodes
const mockLLMResponse = { choices: [{ message: { content: JSON.stringify({ category: 'urgent', confidence: 0.95 }) } }] };

nock('https://api.openai.com')
  .post('/v1/chat/completions')
  .reply(200, mockLLMResponse);
```

Test that:
- Prompt templates produce expected outputs with known inputs
- JSON parsing handles malformed LLM responses gracefully
- Fallback logic triggers when AI confidence is low

## Level 3: Workflow JSON Validation

### Structure Checks

```typescript
import { readFileSync } from 'fs';

interface N8nWorkflow {
  name: string;
  nodes: Array<{ name: string; type: string; parameters: any; credentials?: any }>;
  connections: Record<string, any>;
}

function validateWorkflow(path: string): string[] {
  const workflow: N8nWorkflow = JSON.parse(readFileSync(path, 'utf-8'));
  const errors: string[] = [];

  // Check all nodes have unique names
  const names = workflow.nodes.map(n => n.name);
  const dupes = names.filter((n, i) => names.indexOf(n) !== i);
  if (dupes.length) errors.push(`Duplicate node names: ${dupes.join(', ')}`);

  // Check no orphan nodes (not in connections)
  const connected = new Set(Object.keys(workflow.connections));
  for (const node of workflow.nodes) {
    if (node.type !== 'n8n-nodes-base.webhook' && !connected.has(node.name)) {
      // Check if node is a target of any connection
      const isTarget = Object.values(workflow.connections).some((conns: any) =>
        Object.values(conns).flat().some((c: any) => c.some((t: any) => t.node === node.name))
      );
      if (!isTarget) errors.push(`Orphan node: ${node.name}`);
    }
  }

  // Check credential references exist
  for (const node of workflow.nodes) {
    if (node.credentials) {
      for (const [type, cred] of Object.entries(node.credentials as Record<string, any>)) {
        if (!cred.id) errors.push(`Missing credential ID for ${node.name} (${type})`);
      }
    }
  }

  return errors;
}
```

### What to Validate
- No orphan nodes (disconnected from flow)
- No duplicate node names
- All credential references have valid IDs
- Required parameters are set (not empty strings or defaults)
- Error workflow is configured (settings.errorWorkflow)
- Webhook paths don't conflict between workflows

## Level 4: Integration Tests via n8n API

### Execute Workflow Programmatically

```typescript
const N8N_API = process.env.N8N_API_URL ?? 'http://localhost:5678';
const N8N_KEY = process.env.N8N_API_KEY;

async function executeWorkflow(workflowId: string, data?: Record<string, any>) {
  const response = await fetch(`${N8N_API}/api/v1/workflows/${workflowId}/execute`, {
    method: 'POST',
    headers: { 'X-N8N-API-KEY': N8N_KEY!, 'Content-Type': 'application/json' },
    body: JSON.stringify({ data }),
  });
  return response.json();
}

describe('Order processing workflow', () => {
  it('completes successfully with valid order', async () => {
    const result = await executeWorkflow('workflow-123', { orderId: 'test-001', amount: 50 });
    expect(result.data.status).toBe('success');
    expect(result.data.resultData.runData).toBeDefined();
  }, 30_000); // Integration tests need longer timeout
});
```

### Webhook Testing

```typescript
async function triggerWebhook(path: string, payload: unknown) {
  const response = await fetch(`${N8N_API}/webhook-test/${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  return { status: response.status, body: await response.json() };
}
```

## Error Path Testing

Test error workflows and retry logic:
- Send malformed payloads — verify error workflow triggers
- Mock API timeouts — verify retry logic
- Send payloads that fail validation — verify graceful rejection
- Test rate limit responses (429) — verify backoff behavior

## Environment Isolation

- Use separate n8n instance for tests (Docker: `docker run -p 5679:5678 n8nio/n8n`)
- Test credentials must point to sandbox/mock APIs, never production
- Use env vars: `N8N_API_URL`, `N8N_API_KEY`, `N8N_ENV=test`
- Clean up test data after each run

## Done Criteria

- [ ] Business logic extracted from code nodes and unit tested
- [ ] External API calls mocked in tests
- [ ] AI/LLM steps mocked with deterministic responses
- [ ] Workflow JSON validated (no orphans, no missing credentials)
- [ ] Error paths tested (malformed input, API failures)
- [ ] Integration test executes workflow end-to-end in test environment
- [ ] Webhook endpoints tested with sample payloads
- [ ] Test environment isolated from production
