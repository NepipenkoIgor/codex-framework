---
name: graphql-implement
description: Implement GraphQL APIs — schema design, resolvers, mutations, subscriptions, DataLoader batching, auth, pagination, and federation for .NET (Hot Chocolate) and Node.js (graphql-yoga, Pothos)
metadata:
  version: 1.3
  argument-hint: "server library (Apollo/Hotchocolate/Strawberry), resolvers to implement, auth method"
---

Implement production-ready $ARGUMENTS.


## Tool Integration

- **Language diagnostics**: run available diagnostics tools after every code change to catch type errors before completion
- docs lookup tools: fetch current library docs before implementing — never rely on training data alone

## Documentation

> Use **available docs lookup tools or official docs** when you encounter unknown API syntax, current library versions, or framework-specific configuration. Do not rely on training data for library docs — fetch current docs on demand.

## Stack Detection

Detect from project files:
- `*.csproj` with `HotChocolate` → .NET / Hot Chocolate
- `package.json` with `graphql-yoga` or `@pothos-graphql/core` → Node.js
- If neither, ask user which stack

---

## Schema Design

### Naming Conventions
- Types: PascalCase (`User`, `OrderItem`)
- Fields: camelCase (`firstName`, `createdAt`)
- Enums: SCREAMING_SNAKE_CASE values (`ORDER_STATUS.PENDING`)
- Mutations: verb + noun (`createUser`, `updateOrder`, `deleteComment`)
- Queries: noun or collection (`user`, `users`, `ordersByCustomer`)

### Type Design Principles
- Input types for mutations (never reuse output types as input)
- Payload types for mutation responses (include `errors` field)
- Connection types for pagination (Relay cursor-based)
- Interface types for polymorphism (`Node` interface for global IDs)
- Never expose database IDs directly — use opaque global IDs

---

## .NET — Hot Chocolate

### Project Setup
```csharp
// Program.cs
builder.Services
    .AddGraphQLServer()
    .AddQueryType<Query>()
    .AddMutationType<Mutation>()
    .AddSubscriptionType<Subscription>()
    .AddFiltering()
    .AddSorting()
    .AddProjections()
    .AddAuthorization()
    .AddInMemorySubscriptions();
```

### Code-First Types
```csharp
[QueryType]
public class Query
{
    [UsePaging(IncludeTotalCount = true)]
    [UseProjection]
    [UseFiltering]
    [UseSorting]
    public IQueryable<User> GetUsers(AppDbContext context) => context.Users;

    public async Task<User?> GetUserById(int id, AppDbContext context, CancellationToken ct)
        => await context.Users.FindAsync(new object[] { id }, ct);
}
```

### DataLoader (N+1 Prevention)
```csharp
public class UserByIdDataLoader : BatchDataLoader<int, User>
{
    private readonly IDbContextFactory<AppDbContext> _dbContextFactory;

    public UserByIdDataLoader(
        IDbContextFactory<AppDbContext> dbContextFactory,
        IBatchScheduler batchScheduler,
        DataLoaderOptions? options = null)
        : base(batchScheduler, options)
    {
        _dbContextFactory = dbContextFactory;
    }

    protected override async Task<IReadOnlyDictionary<int, User>> LoadBatchAsync(
        IReadOnlyList<int> keys, CancellationToken ct)
    {
        await using var context = await _dbContextFactory.CreateDbContextAsync(ct);
        return await context.Users
            .Where(u => keys.Contains(u.Id))
            .ToDictionaryAsync(u => u.Id, ct);
    }
}
```

### Mutations with Payload
```csharp
[MutationType]
public class Mutation
{
    public async Task<CreateUserPayload> CreateUser(
        CreateUserInput input, AppDbContext context, CancellationToken ct)
    {
        var user = new User { Name = input.Name, Email = input.Email };
        context.Users.Add(user);
        await context.SaveChangesAsync(ct);
        return new CreateUserPayload(user);
    }
}

public record CreateUserInput(string Name, string Email);
public record CreateUserPayload(User? User, string[]? Errors = null);
```

### Subscriptions
```csharp
[SubscriptionType]
public class Subscription
{
    [Subscribe]
    [Topic("OrderCreated_{customerId}")]
    public Order OnOrderCreated(
        [EventMessage] Order order,
        [ID] int customerId) => order;
}

// Publishing from mutation:
[MutationType]
public class Mutation
{
    public async Task<Order> CreateOrder(
        CreateOrderInput input, AppDbContext context,
        [Service] ITopicEventSender sender, CancellationToken ct)
    {
        var order = new Order { /* ... */ };
        await context.SaveChangesAsync(ct);
        await sender.SendAsync($"OrderCreated_{order.CustomerId}", order, ct);
        return order;
    }
}
```

### Authorization
```csharp
[QueryType]
public class Query
{
    [Authorize(Policy = "Admin")]
    public IQueryable<User> GetUsers(AppDbContext context) => context.Users;

    [Authorize]
    public async Task<User> GetMe(ClaimsPrincipal claims, AppDbContext context, CancellationToken ct)
    {
        var userId = claims.FindFirstValue(ClaimTypes.NameIdentifier);
        return await context.Users.FindAsync(int.Parse(userId!), ct);
    }
}
```

---

## Node.js — graphql-yoga + Pothos

### Project Setup
```typescript
import { createYoga } from 'graphql-yoga';
import { createServer } from 'node:http';
import { schema } from './schema';

const yoga = createYoga({ schema });
const server = createServer(yoga);
server.listen(4000);
```

### Pothos Schema Builder
```typescript
import SchemaBuilder from '@pothos-graphql/core';
import RelayPlugin from '@pothos-graphql/plugin-relay';
import PrismaPlugin from '@pothos-graphql/plugin-prisma';

const builder = new SchemaBuilder<{
  Context: { userId: string | null; prisma: PrismaClient };
  PrismaTypes: PrismaTypes;
}>({
  plugins: [RelayPlugin, PrismaPlugin],
  prisma: { client: prisma },
  relayOptions: { clientMutationId: 'omit', cursorType: 'String' },
});
```

### Type Definitions
```typescript
builder.prismaObject('User', {
  fields: (t) => ({
    id: t.exposeID('id'),
    name: t.exposeString('name'),
    email: t.exposeString('email'),
    orders: t.relation('orders'),
  }),
});

builder.queryField('users', (t) =>
  t.prismaConnection({
    type: 'User',
    cursor: 'id',
    resolve: (query) => prisma.user.findMany({ ...query }),
  })
);
```

### DataLoader (N+1 Prevention)
```typescript
import DataLoader from 'dataloader';

// In context factory:
function createContext() {
  return {
    loaders: {
      userById: new DataLoader<string, User>(async (ids) => {
        const users = await prisma.user.findMany({ where: { id: { in: [...ids] } } });
        const userMap = new Map(users.map(u => [u.id, u]));
        return ids.map(id => userMap.get(id) ?? new Error(`User ${id} not found`));
      }),
    },
  };
}
```

### Mutations
```typescript
const CreateUserInput = builder.inputType('CreateUserInput', {
  fields: (t) => ({
    name: t.string({ required: true }),
    email: t.string({ required: true }),
  }),
});

builder.mutationField('createUser', (t) =>
  t.prismaField({
    type: 'User',
    args: { input: t.arg({ type: CreateUserInput, required: true }) },
    resolve: async (query, _parent, { input }, ctx) => {
      return ctx.prisma.user.create({ ...query, data: input });
    },
  })
);
```

### Subscriptions
```typescript
import { createPubSub } from 'graphql-yoga';

const pubSub = createPubSub<{ 'order:created': [Order] }>();

builder.subscriptionField('onOrderCreated', (t) =>
  t.field({
    type: OrderType,
    subscribe: () => pubSub.subscribe('order:created'),
    resolve: (payload) => payload,
  })
);
```

### Auth Middleware
```typescript
// Auth plugin or field-level
builder.queryField('me', (t) =>
  t.prismaField({
    type: 'User',
    resolve: async (query, _parent, _args, ctx) => {
      if (!ctx.userId) throw new GraphQLError('Unauthorized');
      return ctx.prisma.user.findUniqueOrThrow({ ...query, where: { id: ctx.userId } });
    },
  })
);
```

---

## Pagination

Always use cursor-based (Relay) pagination for lists:
- `first` / `after` for forward pagination
- `last` / `before` for backward pagination
- Return `Connection` type with `edges`, `nodes`, `pageInfo`, `totalCount`

Both Hot Chocolate (`[UsePaging]`) and Pothos (`t.prismaConnection`) support this natively.

## Error Handling

- Field-level errors: return in payload type (`errors: [UserError!]`)
- System errors: throw `GraphQLError` with extensions for error codes
- Never expose stack traces or internal details
- Validation: validate input at resolver level, return structured errors

## Performance Checklist

- [ ] DataLoaders for every relationship resolver (prevents N+1)
- [ ] Pagination on all list fields (never return unbounded lists)
- [ ] Projection/selection: only fetch requested fields from DB
- [ ] Query depth limiting configured (prevent deeply nested attacks)
- [ ] Query complexity analysis enabled (prevent expensive queries)
- [ ] Persisted queries for production (optional, prevents arbitrary queries)

## Done Criteria

- [ ] Schema compiles and introspection works
- [ ] All resolvers have DataLoaders where needed
- [ ] Mutations return payload types with error handling
- [ ] Auth applied to protected fields
- [ ] Pagination on list fields
- [ ] No N+1 queries (verified with query logging)
- [ ] Subscriptions tested with playground
