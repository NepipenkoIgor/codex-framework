---
name: backend-test
description: Write unit and integration tests for backend code in .NET, ASP.NET Core, Node.js, Bun, NestJS, Elysia, TypeScript, or JavaScript
metadata:
  version: 2.0
  argument-hint: "code/module to test, test type (unit/integration), framework, coverage target, external dependencies needed"
---

Write tests for $ARGUMENTS.

## Tool Integration

- Use the repository's existing test framework.
- Run available diagnostics after meaningful code changes.

## Testing Principles

- Prefer behavior and contract testing over implementation-detail testing.
- Focus on validation, error handling, orchestration, side effects, and persistence-sensitive behavior.
- Use the smallest realistic scope that verifies the risk.
- Avoid trivial existence or wiring-only tests.

## Priority Areas

- request and response behavior
- validation and boundary conditions
- retries, idempotency, and async failure paths
- persistence and query correctness
- authorization and security boundaries

## Output Requirements

- Add the most meaningful regression protection for the changed backend behavior.
- Follow the repo's existing testing style.
- State remaining gaps explicitly.
