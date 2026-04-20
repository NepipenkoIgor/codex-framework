---
name: backend-implement-node
description: Node.js 20+ backend patterns — Express/Fastify/NestJS, async/await, Zod validation, Prisma/Drizzle, structured logging
metadata:
  version: 1.0
  domain: backend
  keywords: [node, nodejs, express, fastify, nestjs, typescript, api, rest, prisma, drizzle, zod, pino, bun]
---

# Backend Implement — Node.js

Pair with `backend-implement` for universal rules.

## Async Patterns

- Always `async/await` — never `.then().catch()` chains
- Always `try/catch` in route handlers or use a global error middleware — never let async errors go unhandled
- Never `new Promise()` wrapping when the underlying API already returns a Promise
- Use `Promise.all()` for parallel independent async operations — never sequential `await` when parallelism is possible
- Never use `async` functions as Express middleware without wrapping in error-catching wrapper or using `express-async-errors`

## Validation

- Always validate request input with `zod` at the route level before business logic touches it
- Never trust `req.body`, `req.query`, `req.params` without schema validation
- Use `z.infer<typeof schema>` for TypeScript types derived from Zod schemas — never duplicate type definitions
- Return 400 with structured error detail on validation failure — never 500 for bad input

## Error Handling

- Use a centralized error handler middleware: Express 4-arg `(err, req, res, next)`, Fastify `setErrorHandler`
- Define typed error classes extending `Error` with a `statusCode` property
- Use `pino` for structured logging — never `console.log/error` in production code
- Never expose `err.stack` in API responses — log it server-side, return only `code` + `message` to client

## ORM / Database

- Use `prisma` (schema-first, excellent TypeScript DX) or `drizzle` (SQL-first, lightweight) — never raw `pg`/`mysql2` in business logic
- Always parameterized queries or ORM builders — never string concatenation for SQL
- Wrap multi-step DB operations in transactions — never allow partial failure to leave inconsistent state
- Never run migrations in application startup — always a separate migration step in CI/CD
- Use `prisma.$transaction()` or drizzle `db.transaction()` for atomic operations

## NestJS Specifics

- Always `ValidationPipe` globally with `transform: true, whitelist: true`
- Inject dependencies via constructor — never manually instantiate services with `new`
- Use `@UseGuards()` for auth enforcement — never inline token checks in controllers
- Feature-scoped modules — never one giant `AppModule` containing all providers

## Fastify Specifics

- Always define route schemas (`schema: { body, params, querystring, response }`) — enables validation + fast serialization
- Use `fastify-plugin` for decorators and shared functionality — never mutate fastify instance outside plugins
- Use `@fastify/rate-limit` for rate limiting — never manual counting logic

## Security

- Always use `helmet` for HTTP security headers on Express/Fastify
- Always rate-limit auth endpoints (`/login`, `/register`, `/forgot-password`)
- Never store secrets in code — always `process.env` via validated env schema (`zod` + `dotenv` or `@t3-oss/env-core`)
- Always hash passwords with `bcrypt` or `argon2` — never `md5`/`sha1`/plain storage

## Hard Rules

- Never `.then().catch()` — `async/await` always
- Never raw SQL string concatenation — ORM or parameterized queries always
- Never expose stack traces in API responses
- Never unvalidated request input into business logic
- Never synchronous file I/O (`fs.readFileSync`) inside request handlers
- Never `console.log` in production — `pino` or equivalent structured logger always

## Done Criteria

- All routes have Zod input validation
- All async handlers have error handling (try/catch or global error middleware)
- No raw SQL string concatenation anywhere
- No stack traces in response bodies
- `pino` (or equivalent) used — no `console.log/error`
- LSP reports zero errors
