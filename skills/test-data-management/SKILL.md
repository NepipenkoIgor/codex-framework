---
name: test-data-management
description: Implement test data factories, database seeding, fixture management, and anonymized production data for testing
metadata:
  version: 1.2
  argument-hint: "data model complexity, test scenarios, volume requirements, anonymization needs"
---

Implement test data management for $ARGUMENTS.


## Factory Pattern (TypeScript)

```typescript
import { faker } from '@faker-js/faker';

interface UserFactory {
  build(overrides?: Partial<User>): User;
  create(overrides?: Partial<User>): Promise<User>;
  buildMany(count: number, overrides?: Partial<User>): User[];
  createMany(count: number, overrides?: Partial<User>): Promise<User[]>;
}

function defineFactory<T>(defaults: () => T, persist: (data: T) => Promise<T>): Factory<T> {
  return {
    build: (overrides = {}) => ({ ...defaults(), ...overrides }),
    create: async (overrides = {}) => persist({ ...defaults(), ...overrides }),
    buildMany: (count, overrides = {}) => Array.from({ length: count }, () => ({ ...defaults(), ...overrides })),
    createMany: async (count, overrides = {}) =>
      Promise.all(Array.from({ length: count }, () => persist({ ...defaults(), ...overrides }))),
  };
}

const userFactory = defineFactory(
  () => ({
    id: faker.string.uuid(),
    email: faker.internet.email(),
    name: faker.person.fullName(),
    role: 'user' as const,
    createdAt: faker.date.recent({ days: 30 }),
  }),
  async (data) => db.users.create({ data }),
);

const orderFactory = defineFactory(
  () => ({
    id: faker.string.uuid(),
    userId: faker.string.uuid(),
    status: 'pending' as const,
    total: parseFloat(faker.commerce.price({ min: 10, max: 500 })),
    items: [{ productId: faker.string.uuid(), quantity: faker.number.int({ min: 1, max: 5 }), price: parseFloat(faker.commerce.price()) }],
  }),
  async (data) => db.orders.create({ data }),
);

// Usage in tests
const user = await userFactory.create({ role: 'admin' });
const orders = await orderFactory.createMany(5, { userId: user.id, status: 'completed' });
```

## Factory Pattern (.NET)

```csharp
public class UserFactory
{
    private readonly Faker<User> _faker = new Faker<User>()
        .RuleFor(u => u.Id, f => f.Random.Guid())
        .RuleFor(u => u.Email, f => f.Internet.Email())
        .RuleFor(u => u.Name, f => f.Person.FullName)
        .RuleFor(u => u.Role, "user")
        .RuleFor(u => u.CreatedAt, f => f.Date.Recent(30));

    public User Build(Action<User>? configure = null)
    {
        var user = _faker.Generate();
        configure?.Invoke(user);
        return user;
    }

    public async Task<User> CreateAsync(AppDbContext db, Action<User>? configure = null)
    {
        var user = Build(configure);
        db.Users.Add(user);
        await db.SaveChangesAsync();
        return user;
    }

    public List<User> BuildMany(int count) => _faker.Generate(count);
}
```

## Seed Scripts

```typescript
// seeds/development.ts
export async function seed(db: Database) {
  await db.transaction(async (tx) => {
    // Idempotent: clear and re-seed
    await tx.execute('TRUNCATE users, orders, products CASCADE');

    const admin = await userFactory.create({ email: 'admin@dev.local', role: 'admin' });
    const users = await userFactory.createMany(10);

    const products = await productFactory.createMany(20);

    for (const user of users) {
      const orderCount = faker.number.int({ min: 0, max: 5 });
      await orderFactory.createMany(orderCount, {
        userId: user.id,
        items: faker.helpers.arrayElements(products, { min: 1, max: 3 }).map(p => ({
          productId: p.id, quantity: faker.number.int({ min: 1, max: 3 }), price: p.price,
        })),
      });
    }
  });
}

// Run: npx tsx seeds/development.ts
```

## Fixture Management

```typescript
// fixtures/checkout-flow.ts
export async function setupCheckoutFixture(db: Database) {
  const user = await userFactory.create({ role: 'user' });
  const product = await productFactory.create({ price: 29.99, stock: 100 });
  const cart = await cartFactory.create({ userId: user.id, items: [{ productId: product.id, quantity: 2 }] });

  return { user, product, cart, cleanup: async () => {
    await db.execute('DELETE FROM carts WHERE id = $1', [cart.id]);
    await db.execute('DELETE FROM products WHERE id = $1', [product.id]);
    await db.execute('DELETE FROM users WHERE id = $1', [user.id]);
  }};
}

// In test
let fixture: Awaited<ReturnType<typeof setupCheckoutFixture>>;
beforeEach(async () => { fixture = await setupCheckoutFixture(db); });
afterEach(async () => { await fixture.cleanup(); });
```

## Data Anonymization

```typescript
// Anonymize production snapshot for staging
const anonymizationRules: Record<string, ColumnRule[]> = {
  users: [
    { column: 'email', transform: (row) => `user-${row.id}@staging.local` },
    { column: 'name', transform: () => faker.person.fullName() },
    { column: 'phone', transform: () => faker.phone.number() },
    { column: 'password_hash', transform: () => hashSync('staging-password', 10) },
  ],
  orders: [
    { column: 'shipping_address', transform: () => faker.location.streetAddress() },
    { column: 'billing_address', transform: () => faker.location.streetAddress() },
  ],
  payments: [
    { column: 'card_last4', transform: () => '4242' },
    { column: 'stripe_customer_id', transform: () => `cus_staging_${faker.string.alphanumeric(14)}` },
  ],
};

async function anonymizeDatabase(sourceUrl: string, targetUrl: string) {
  for (const [table, rules] of Object.entries(anonymizationRules)) {
    const rows = await sourceDb.query(`SELECT * FROM ${table}`);
    for (const row of rows) {
      for (const rule of rules) {
        row[rule.column] = rule.transform(row);
      }
    }
    await targetDb.batchInsert(table, rows);
  }
}
```

## Snapshot Testing Data

```typescript
// Create deterministic snapshots with seeded faker
function createDeterministicData(seed: number) {
  faker.seed(seed);
  return {
    users: userFactory.buildMany(5),
    orders: orderFactory.buildMany(10),
  };
}

// In test — same seed = same data every time
const data = createDeterministicData(42);
expect(data).toMatchSnapshot();
```

## Anti-Patterns

- Shared mutable test data across suites — concurrent writes cause race conditions and flaky failures
- Production data in tests without anonymization — PII violation; always anonymize before importing snapshots
- Random data without a deterministic seed — failures are non-reproducible and hard to debug
- Seeding in `beforeAll` shared across tests — hidden coupling; one test's mutation breaks all others

## Workflow

1. Identify entities and their relationships
2. Create factories with sensible defaults using faker
3. Build scenario-specific fixtures (checkout, onboarding, etc.)
4. Create seed scripts for development and staging
5. Add anonymization pipeline for production snapshots
6. Integrate factory usage into existing test suites
7. Add CI step to verify seed scripts run without errors

Done: ✓ factories for all core entities ✓ faker defaults with override support ✓ scenario fixtures with cleanup ✓ seed scripts for dev/staging ✓ data anonymization rules for PII ✓ deterministic mode for snapshot tests ✓ parallel-safe with UUID keys ✓ CI verification of seeds
