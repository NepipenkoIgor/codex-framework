---
name: backend-test-node
description: Node.js API testing with vitest/jest, supertest, MSW, database integration patterns
metadata:
  version: 1.0
  domain: backend
  keywords: [node, nodejs, testing, vitest, jest, supertest, msw, integration test, api test, prisma test]
---

# Backend Test — Node.js

Pair with `backend-test` for universal testing principles.

## Setup

- Use `vitest` for new projects — faster, native ESM, compatible with Vite ecosystem
- Use `jest` only when already established in the codebase — no migration mid-project
- Use `supertest` for HTTP integration tests against the Express/Fastify app instance
- Use a real test database — never mock Prisma/Drizzle/ORM (schema bugs hide behind mocks)
- Use separate test DB with `.env.test` — never run tests against development or production DB

## Database

- Run migrations before test suite: `prisma migrate deploy` or `drizzle-kit push` in test setup
- Use `beforeEach` to seed required fixtures, `afterEach` to clean up — never share state across tests
- Use transactions rolled back after each test for isolation when supported
- Never mock `prisma.$transaction` or query methods — test the real DB behavior

## HTTP Testing with supertest

- Test at HTTP layer: `await request(app).post('/users').send(body).expect(201)`
- Always assert response status code AND response body shape — never just status
- Test auth enforcement: always include a test that the endpoint returns 401/403 without valid token
- Test validation: always include a test that invalid input returns 400 with error detail

## External Services

- Use MSW (`msw/node`) to mock external HTTP services (Stripe, SendGrid, third-party APIs)
- Define MSW handlers in `src/mocks/handlers.ts`, server in `src/mocks/server.ts`
- Use `server.use()` per-test for error/edge-case overrides
- Always `server.resetHandlers()` in `afterEach` — never let handler overrides leak

## NestJS Testing

- Use `Test.createTestingModule()` for unit tests of services and controllers
- Use `@nestjs/testing` `NestApplication` + supertest for integration tests
- Override providers with `{ provide: MyService, useValue: mockService }` — only mock external dependencies
- Never mock services under test — only mock their dependencies

## Hard Rules

- Never mock ORM/DB client — use real test database always
- Never share mutable state between tests — always clean up in `afterEach`
- Always test auth enforcement (401/403) on protected endpoints
- Always test validation error (400) on endpoints with input schemas
- Never use `setTimeout` in tests — use `vi.useFakeTimers()` / `jest.useFakeTimers()` for time

## Done Criteria

- All API endpoints have integration tests via supertest
- Auth enforcement tested (401 without token, 403 with wrong role)
- Validation rejection tested (400 with invalid body)
- Real DB used — no ORM mocks
- MSW handles all external HTTP calls
- Tests isolated — no shared mutable state between tests
