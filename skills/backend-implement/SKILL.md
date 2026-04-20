---
name: backend-implement
description: Implement new backend features in .NET, ASP.NET Core, Node.js, Bun, NestJS, Elysia, TypeScript, or JavaScript applications
metadata:
  version: 3.0
  argument-hint: "feature/endpoint, tech stack (NestJS/Express/ASP.NET), dependencies (DB/cache/auth), testing strategy, deployment target"
---

Implement $ARGUMENTS.

## Architecture Alignment

If an approved architecture or schema already exists:

- treat it as the source of truth
- do not redesign boundaries unless explicitly asked
- ask for clarification instead of inventing alternatives

If architecture is missing:

- propose the minimum viable implementation plan before coding
- avoid adding architectural layers without clear value

## Tool Integration

- Use the available language diagnostics after meaningful code changes.
- Use the available docs lookup tool when framework or library syntax is uncertain.

## Core Principles

- Follow the existing project conventions and boundaries.
- Keep transport, validation, business logic, and persistence concerns separated.
- Prefer explicit contracts for requests, responses, commands, events, and jobs.
- Handle timeout, retry, cancellation, and idempotency deliberately.
- Avoid duplicated logic and unnecessary I/O.

## Validation and Contracts

- Validate inputs at the boundary.
- Keep runtime validation and compile-time typing aligned.
- Avoid leaking persistence entities into API contracts.
- Keep list endpoints bounded with paging or cursors.

## Persistence

- Use the project's established persistence technology.
- Prefer efficient query shaping and projection.
- Keep transaction boundaries explicit.
- Avoid unnecessary abstraction layers.

## API Documentation

- Document new or changed HTTP endpoints as part of the same task.
- Respect the repo's existing OpenAPI or Swagger approach.
- Never leave new endpoints undocumented.

## Reliability

- Handle expected failures explicitly.
- Avoid sync-over-async and hidden side effects.
- Preserve useful error context without leaking sensitive information.

## Verification

1. Run the relevant diagnostics or type checks.
2. Run targeted tests when possible.
3. Verify critical error paths and changed contracts.

## Output Requirements

- Produce production-ready code in the repository's style.
- Keep contracts explicit.
- State assumptions where context is missing.
