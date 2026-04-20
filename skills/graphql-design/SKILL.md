---
name: graphql-design
description: Design GraphQL APIs — schema modeling, query/mutation/subscription patterns, authentication, pagination, error handling, and federation
metadata:
  version: 1.6
  argument-hint: "API domain, schema-first vs code-first, auth approach, subscriptions needed (yes/no)"
---

Design or implement GraphQL for $ARGUMENTS following schema-first principles.

## Tool Integration

- **Language diagnostics**: run available diagnostics tools after every code change to catch type errors before completion
- docs lookup tools: fetch current library docs before implementing — never rely on training data alone

## Documentation

> Use **available docs lookup tools or official docs** for current Apollo, urql, DataLoader, graphql-scalars, graphql-ws, StrawberryShake, and Hot Chocolate docs. Do not rely on training data for library configuration syntax.

## Schema Design Principles

- **Schema-first**: Define the schema before writing resolvers — the schema is the contract
- **Client-driven**: Design types around what the UI needs, not database tables
- **Explicit nullability**: Non-null (!) by default, nullable only when meaningful
- **Pagination**: Relay-style connections (edges/nodes/pageInfo) for all list fields
- **Input types**: Separate Input types for mutations — never reuse output types
- **Naming**: PascalCase types, camelCase fields, UPPER_SNAKE enums
- **Deprecation**: Use @deprecated with reason — never remove fields without deprecation

### Schema Evolution

- Additive changes are safe: new types, fields, enum values, arguments with defaults
- Never change the type of an existing field — add new field, deprecate old
- Required arguments cannot be added to existing fields

## Cursor-Based Pagination (Relay)

```graphql
type Query {
  users(first: Int, after: String, last: Int, before: String, filter: UserFilter): UserConnection!
}
type UserConnection { edges: [UserEdge!]!; pageInfo: PageInfo!; totalCount: Int! }
type UserEdge { node: User!; cursor: String! }
type PageInfo {
  hasNextPage: Boolean!; hasPreviousPage: Boolean!
  startCursor: String; endCursor: String
}
```

Rules: cursor is opaque (base64 encode sort key + tiebreaker ID); default 20 items, max 100; enforce server-side.

## N+1 Prevention with DataLoader

- Use DataLoader for ALL relationships — never query inside a resolver loop
- Request-scoped instances (new per request, never shared)
- Return results in SAME ORDER as input IDs
- Return Error for missing items, not null (unless null is valid)
- Use maxBatchSize to prevent oversized IN clauses (default: 1000)
- Clear cache after mutations: `loaders.userLoader.clear(userId)`

> Use available docs lookup tools or official docs to fetch current DataLoader docs for implementation syntax.

## Error Handling

### Union Types for Expected Errors (Preferred)

```graphql
union CreateUserResult = User | ValidationError | DuplicateEmailError
type ValidationError { message: String!; field: String! }
```

- Use union types for ALL expected business errors (validation, conflicts, not found)
- Reserve GraphQL errors for unexpected failures (server errors, auth)
- Use error codes for machine-readable classification: `VALIDATION_ERROR`, `NOT_FOUND`, `DUPLICATE`

## Custom Scalars and Input Validation

```graphql
scalar DateTime  # ISO 8601
scalar Email     # Validated email
scalar UUID      # UUID v4
```

Use `graphql-scalars` library for standard scalars. Validate at schema level — resolvers should not re-validate scalar constraints.

## Security

- Max depth: 10-15 levels; max complexity budget (e.g., 1000) — reject before execution
- Production: whitelist known queries (persisted queries), reject unknown
- Authorization: implement at resolver level, not schema level; use directive-based auth

## Subscriptions

```graphql
type Subscription {
  messageAdded(channelId: ID!): Message!
}
```

- Use graphql-ws protocol (NOT legacy subscriptions-transport-ws)
- Authenticate on WebSocket connection, not per subscription
- Filter server-side — never send every event to every client
- Multi-server: Redis pub/sub backplane

## Federation vs Stitching

| Factor | Stitching | Federation |
|--------|-----------|-----------|
| Team size | Small (1-3) | Large (3+) |
| Services | 2-5 | 5+ |
| Independent deploy | No | Yes |
| Tooling | graphql-tools | Apollo Federation / GraphQL Mesh |

## Code Generation

- Run codegen in CI — fail build if types out of date
- Never manually edit generated files
- Use mappers to separate GraphQL types from database models
- Fragment colocation: each component defines its data needs

## Frontend Client Integration

> Use available docs lookup tools or official docs to fetch current client library docs for setup and usage patterns.

### Angular + Apollo Client

- `provideApollo()` in `app.config.ts`; `inject(Apollo)` in services
- Signal-based query: `toSignal(apollo.watchQuery({ query }).valueChanges)`
- Codegen: `@graphql-codegen/typescript-apollo-angular`

### Vue / Nuxt + Apollo/Urql

- `@vue/apollo-composable`: `useQuery()`, `useMutation()` in `<script setup>`
- Nuxt: `@nuxtjs/apollo` module with `useAsyncQuery()` for SSR
- Urql alternative: `@urql/vue` with `provideClient()` + `useQuery()`

### SvelteKit + Urql/Houdini

- `@urql/svelte`: `queryStore()` with runes
- Houdini (SvelteKit-native): automatic SvelteKit load function integration

### Next.js App Router

- Server Component: `graphql-request` directly — no client library needed
- Client Component: `@apollo/client` with `@apollo/experimental-nextjs-app-support`
- Server Action with GraphQL mutation for form submissions

### Blazor + StrawberryShake

- `dotnet graphql init https://api.example.com/graphql` generates typed C# client
- Use `GraphQL.Client` NuGet for simpler queries

### React + Urql/Relay/TanStack Query

- urql: `useQuery()`, `useMutation()` with `graphcache` for normalized caching
- Relay: `useLazyLoadQuery()`, `useFragment()` for colocated data requirements
- TanStack Query + graphql-request: `useQuery({ queryFn: () => client.request(GET_ITEMS) })`

## Anti-Patterns

- Resolvers making direct DB queries without DataLoader — guaranteed N+1
- No query depth/complexity limits — deeply nested queries are a DoS vector
- Offset-based pagination — page drift on concurrent inserts; use Relay cursors
- Generic "error" field instead of typed union errors
- Nullable everywhere instead of explicit nullability

## Implementation Workflow

1. Design schema: types, queries, mutations, subscriptions
2. Define pagination (Relay connections) and error handling (union types)
3. Implement DataLoaders for all relationships
4. Implement resolvers — thin, delegate to services
5. Add security: depth limiting, complexity analysis, authorization
6. Set up code generation for server and client types

## Done Criteria

- Schema well-typed with clear nullability and descriptions
- All lists use Relay cursor-based pagination with totalCount
- All relationships use DataLoader (no N+1)
- Mutations return typed results (union types for expected errors)
- Query depth and complexity limits enforced
- Client gets generated types
- Authorization checked at resolver level for all protected operations
