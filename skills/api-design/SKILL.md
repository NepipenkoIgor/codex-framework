---
name: api-design
description: Design RESTful APIs, contracts, versioning, pagination, webhooks, and OpenAPI specifications
metadata:
  version: 1.5
  argument-hint: "API type (REST/GraphQL/gRPC), auth method (JWT/OAuth/API key), versioning strategy, pagination method, target resources/endpoints"
---

Design the API for $ARGUMENTS.

## Tool Integration

- **Language diagnostics**: run available diagnostics tools after every code change to catch type errors before completion
- docs lookup tools: fetch current library docs before implementing — never rely on training data alone

## Documentation

> Use available docs lookup tools or official docs when you encounter unknown API syntax, current library versions, or framework-specific configuration. Do not rely on training data for library docs — fetch current docs on demand.

## Example

Designing a task management API for a project management SaaS:

```yaml
# Resource model and endpoint design
# Base URL: /api/v1

# Tasks resource
GET    /projects/{projectId}/tasks          # List tasks (paginated, filterable)
POST   /projects/{projectId}/tasks          # Create task
GET    /projects/{projectId}/tasks/{taskId}  # Get task
PATCH  /projects/{projectId}/tasks/{taskId}  # Update task (partial)
DELETE /projects/{projectId}/tasks/{taskId}  # Delete task
POST   /projects/{projectId}/tasks/{taskId}/assign  # Non-CRUD action

# Request — Create task
POST /api/v1/projects/proj_abc/tasks
Content-Type: application/json
{
  "title": "Implement login flow",
  "description": "OAuth2 PKCE with Google provider",
  "priority": "high",
  "assigneeId": "usr_456",
  "dueDate": "2026-04-15"
}

# Response — 201 Created
Location: /api/v1/projects/proj_abc/tasks/task_789
{
  "id": "task_789",
  "title": "Implement login flow",
  "description": "OAuth2 PKCE with Google provider",
  "priority": "high",
  "status": "todo",
  "assignee": { "id": "usr_456", "name": "Jane Doe" },
  "dueDate": "2026-04-15",
  "createdAt": "2026-03-21T10:30:00Z",
  "createdBy": { "id": "usr_123", "name": "John Smith" }
}

# Response — List with cursor pagination
GET /api/v1/projects/proj_abc/tasks?status=todo,in_progress&sort=priority:desc&limit=20
{
  "data": [ ... ],
  "pagination": {
    "cursor": "eyJpZCI6InRhc2tfNzg5In0",
    "hasMore": true,
    "total": 47
  }
}
```

Output requirements:

- Start with a short API design summary
- Define resource model and URL structure
- Specify request/response contracts with explicit DTOs
- Define pagination, filtering, and sorting approach
- Specify versioning, auth, and rate limiting strategy
- Include webhook design if event delivery is needed
- Provide OpenAPI outline or schema definitions

OpenAPI specification patterns:

Spec structure:
- Use OpenAPI 3.1 (or 3.0.3 for broader tooling compatibility)
- Organize paths by resource: group all /users endpoints together, all /orders together
- Use tags to group endpoints by domain area in documentation
- Define reusable schemas in components/schemas; reference with $ref everywhere
- Define reusable parameters in components/parameters for shared query params (pagination, filtering)
- Define reusable responses in components/responses for standard error shapes

Schema definition best practices:
- Use required array to enforce mandatory fields — do not rely on consumers knowing
- Use enum for known value sets; document each enum value with description
- Use oneOf/anyOf for polymorphic responses with discriminator field
- Use format for string types: date-time, email, uri, uuid — enables client validation
- Use readOnly and writeOnly to distinguish create/response fields in shared schemas
- Set minLength, maxLength, minimum, maximum for input validation boundaries
- Use nullable: true (OAS 3.0) or type: ["string", "null"] (OAS 3.1) for optional fields

Example request/response pairs:
- Include examples for every endpoint in the spec — they serve as documentation AND test fixtures
- Use example at the property level for simple cases
- Use examples (plural) at the media type level for complex scenarios (success, error, edge case)
- Keep examples realistic — use plausible data, not "string", "test", or "foo"

Security scheme definitions:
- Define securitySchemes in components: bearerAuth (JWT), apiKey (header or query), oauth2 (flows)
- Apply security globally for authenticated APIs; override per-endpoint for public routes
- Document scopes for OAuth2; align with authorization model

Spec validation in CI:
- Validate spec with spectral, redocly, or swagger-cli on every PR
- Check for breaking changes with oasdiff or optic between spec versions
- Generate and publish API docs automatically from spec (Redoc, Swagger UI)

Contract-first workflow:
- Write the OpenAPI spec first, before any implementation code
- Generate server stubs from spec: NSwag (.NET), openapi-generator (Node.js/TS)
- Generate typed client SDKs from spec for frontend and integration consumers
- Run contract tests in CI: validate implementation responses against spec schemas

Idempotency patterns:

Idempotency key design:
- Accept Idempotency-Key header on POST/PATCH endpoints that create or mutate
- Store key → response mapping server-side with TTL (24-48 hours typical)
- Return cached response for duplicate keys — same status, same body
- Return 409 Conflict if same key is used with different request body
- Generate keys client-side: UUID v4 or deterministic hash of operation parameters

Safe retry design:
- GET, PUT, DELETE are inherently idempotent — no special handling needed
- POST create: use idempotency key or unique constraint on natural key to prevent duplicates
- POST action (trigger workflow, send notification): always require idempotency key
- Return Retry-After header with 429 and 503 responses

Batch and bulk API patterns:

Batch request design:
- POST /resources/batch with array body for bulk create/update
- Limit batch size (100-1000 items); return 400 if exceeded
- Return per-item results: { results: [{ id, status, error? }] }
- Use 207 Multi-Status when some items succeed and others fail
- Process items independently — one failure should not roll back others (unless explicitly transactional)

Bulk delete:
- DELETE /resources with filter query params or POST /resources/bulk-delete with ID array
- Return count of deleted items; warn if count is large (>100)
- Support dry-run mode: ?dryRun=true returns what would be deleted without acting

HATEOAS and hypermedia:
- Include self links in resource responses for discoverability
- Include action links for state transitions: { links: { approve: "/orders/123/approve" } }
- Use standard relation types (self, next, prev, first, last) for pagination links
- Do not over-engineer hypermedia — use it where it reduces client coupling

API testing strategy:
- Contract tests: validate implementation against OpenAPI spec
- Integration tests: test full request lifecycle with real HTTP calls
- Schema validation tests: verify request/response shapes match DTOs
- Error scenario tests: test all 4xx/5xx responses with appropriate payloads
- Performance tests: verify response times under expected load
- Security tests: test auth bypass, injection, rate limiting enforcement

Common API design anti-patterns to avoid:
- Exposing database schema directly as API contract (leaks internal structure)
- Using verb-based URLs (POST /createUser) instead of resource-based (POST /users)
- Returning different error formats from different endpoints
- Silently ignoring unknown fields in requests (can mask client bugs)
- Using 200 for everything with a "success: false" body field
- Pagination without total count or next page indicator
- Breaking changes in a live API version (removing fields, changing types)
- Nested resources deeper than one level (/users/123/orders/456/items/789)
- Missing Content-Type headers or inconsistent media types
- Designing APIs around frontend page layouts instead of domain resources

## Structured Output Contract
- **Status**: `done` | `partial` | `blocked`
- **Changed**: `[file.ext: +lines/-lines, ...]` — list every modified file
- **Notes**: blockers or non-obvious decisions only — omit if none

Do NOT return prose summaries or recaps.
