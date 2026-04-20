---
name: ddd-patterns
description: Design domain-driven systems with bounded contexts, aggregates, entities, value objects, domain events, domain services, repositories, and anti-corruption layers
metadata:
  version: 1.3
  argument-hint: "domain name, bounded contexts, aggregate root entities, domain events, integration points with other services, framework (Node.js/ASP.NET)"
---

Design domain-driven architecture for $ARGUMENTS.


## Strategic DDD

### Bounded Context Identification

A bounded context is a linguistic and model boundary. The same concept has different meanings across contexts (e.g., "Customer" in Sales = preferences; in Shipping = address; in Billing = payment method).

Discovery: identify business capabilities, map ubiquitous language per capability (where terms diverge, draw a boundary), identify data ownership, identify integration points, choose mapping pattern.

### Context Mapping Patterns

| Pattern | When to use |
|---------|-------------|
| Shared Kernel | Closely collaborating teams, stable shared concepts |
| Customer-Supplier | Clear provider/consumer with upstream accommodation |
| Conformist | Upstream won't change, downstream accepts their model |
| Anti-Corruption Layer (ACL) | Upstream model is foreign, legacy, or unstable |
| Open Host Service (OHS) | Multiple consumers need stable documented API |
| Published Language (PL) | Industry standards, shared event schemas |
| Separate Ways | Cost of integration exceeds benefit |

### Anti-Corruption Layer

The ACL translates external models to domain types at the bounded context boundary. External types never cross the ACL. Only the ACL knows about the external model.

```typescript
// ACL: translate Stripe model to domain model
class PaymentGatewayTranslator {
  toDomain(stripe: StripePaymentIntent): PaymentResult {
    return {
      paymentId: PaymentId.from(stripe.id),
      amount: Money.fromCents(stripe.amount, stripe.currency),
      status: this.mapStatus(stripe.status),
      receiptUrl: stripe.charges.data[0]?.receipt_url ?? null,
    };
  }
}
```

.NET: same pattern with `record` types and `switch` expressions for status mapping.

## Tactical DDD Building Blocks

| Block | Purpose | Identity |
|-------|---------|----------|
| Entity | Object with identity, mutable state, lifecycle | By ID |
| Value Object | Immutable, defined by attributes, no identity | By value equality |
| Aggregate | Consistency boundary, cluster of entities/VOs | Aggregate root ID |
| Domain Event | Something that happened in the domain | Event ID |
| Domain Service | Stateless operation spanning multiple aggregates | N/A |
| Repository | Abstracts persistence for aggregates | N/A |

### Value Objects

Immutable, equality by value, self-validating, no identity. Replace primitive obsession: `Money` not `decimal`, `EmailAddress` not `string`.

```typescript
class Money {
  private constructor(readonly amount: number, readonly currency: string) {
    if (!Number.isFinite(amount) || amount < 0) throw new Error('Invalid amount');
  }
  static fromCents(cents: number, currency: string): Money { return new Money(cents / 100, currency.toUpperCase()); }
  add(other: Money): Money { this.assertSameCurrency(other); return new Money(this.amount + other.amount, this.currency); }
  multiply(factor: number): Money { return new Money(Math.round(this.amount * factor * 100) / 100, this.currency); }
  equals(other: Money): boolean { return this.amount === other.amount && this.currency === other.currency; }
}
```

.NET: use `record` for structural equality. Same validation in constructor.

### Aggregates

Aggregate root is the only entry point. One aggregate per transaction. Keep small (only data for invariants). Reference other aggregates by ID. Return domain events from command methods.

```typescript
class Order {
  private lineItems: OrderLineItem[] = [];
  private status: OrderStatus;

  addLineItem(productId: ProductId, quantity: Quantity, unitPrice: Money): void {
    if (this.status !== OrderStatus.Draft) throw new OrderNotModifiableError(this.id);
    if (this.lineItems.length >= 50) throw new OrderItemLimitExceededError(this.id);
    if (this.lineItems.some(li => li.productId.equals(productId))) throw new DuplicateProductError(this.id, productId);
    this.lineItems.push(new OrderLineItem(LineItemId.generate(), productId, quantity, unitPrice));
  }

  confirm(): OrderConfirmedEvent {
    if (this.lineItems.length === 0) throw new EmptyOrderError(this.id);
    this.status = OrderStatus.Confirmed;
    return new OrderConfirmedEvent(this.id, this.totalAmount, new Date());
  }
}
```

### Domain Events

Events signal what happened. Aggregates collect events internally; application service dispatches after persistence.

```typescript
class OrderService {
  async confirmOrder(orderId: string): Promise<void> {
    const order = await this.orderRepo.findById(OrderId.from(orderId));
    order.confirm();
    await this.orderRepo.save(order);
    for (const event of order.pullDomainEvents()) { await this.eventBus.publish(event); }
  }
}
```

### Domain Services

Use when an operation spans multiple aggregates (e.g., transfer between accounts). Load both aggregates, execute domain logic, save separately (eventual consistency).

### Repositories

Interface in domain layer, implementation in infrastructure. One per aggregate root. Returns domain objects, not persistence entities. Methods: `findById`, `save`, `findByX` with pagination.

## Application Services (Use Cases)

Orchestrate: validate command -> load data -> create/modify aggregate -> persist -> publish events. No domain logic -- delegate to aggregates and domain services. Handle cross-cutting: transactions, authorization, logging. Translate between DTOs and domain types.

## Invariant Validation Placement

| Layer | What to validate |
|-------|-----------------|
| Transport | Input format, required fields, types (Zod/FluentValidation) |
| Application service | Authorization, existence checks, cross-aggregate rules |
| Aggregate | Business invariants within consistency boundary |
| Value object | Self-validity (email format, money non-negative) |

## Code Organization

```
src/domain/{aggregate}/ — aggregate root, entities, VOs, events, errors, repository interface
src/domain/shared/ — shared value objects (Money, Email, Quantity)
src/application/{aggregate}/ — use cases, command schemas
src/infrastructure/persistence/ — repository implementations
src/infrastructure/integrations/ — external service adapters + ACLs
```

## Anti-Patterns

- Anemic domain model: all logic in services, aggregates are just data bags
- Cross-aggregate transactions: modifying multiple aggregates in one DB transaction violates consistency boundaries
- Primitive obsession: `string` for email, `number` for money — use value objects
- Repository for non-root entities: bypasses aggregate invariants
- Shared database between bounded contexts: creates implicit coupling that defeats context isolation

## Output Format

```
Bounded Contexts:     [list with ubiquitous language ownership]
Context Map:          [relationships with patterns]
Aggregates:           [per context with invariants]
Value Objects:        [shared and context-specific]
Domain Events:        [events crossing boundaries]
Repositories:         [per aggregate root]
ACLs:                 [for external integrations]
Application Services: [use case orchestration]
```

## Done Criteria

- Bounded contexts have clear linguistic boundaries
- Context mapping defines explicit integration patterns
- Aggregates enforce all invariants within their consistency boundary
- Value objects replace primitives for domain concepts
- Domain events communicate across boundaries
- Repositories abstract persistence with domain-layer interfaces
- ACLs insulate domain from external models
- Application services orchestrate without containing domain logic
- Code organization reflects domain boundaries
