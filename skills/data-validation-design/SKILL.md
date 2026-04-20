---
name: data-validation-design
description: Design data validation architecture covering input validation, schema-driven validation, sanitization, error formatting, contract validation, file validation, configuration validation, and pipeline data quality
metadata:
  version: 1.3
  argument-hint: "validation scope (input/schema/API contract/file), framework (Zod/Yup/Joi/ASP.NET), error handling format, sanitization requirements, data source type"
---

Design the data validation architecture for $ARGUMENTS.

Frameworks and tools in scope:
- Validation: Zod, Joi, class-validator, FluentValidation, JSON Schema, AJV
- Runtime: .NET / ASP.NET Core, Node.js / Bun, NestJS, Elysia, Python / FastAPI
- Database: PostgreSQL, SQL Server, MySQL constraints
- API: REST, GraphQL, gRPC, webhooks
- Files: MIME detection, magic bytes, antivirus integration
- Config: environment variables, feature flags, startup validation

Core validation principles:

- Validate at boundaries, trust within; once data enters a validated boundary, downstream code can assume correctness
- Schema-first: define the shape before writing the handler; the schema is the contract
- Fail fast with clear errors; never silently accept bad data
- Validation is security: every unvalidated input is an attack surface
- Keep validation logic close to the contract it enforces
- Separate validation concerns: format validation, business rules, authorization checks
- Parse, do not validate: transform unknown input into known typed structures
- Make invalid states unrepresentable through types and schemas

Validation completeness checklist:

- Identify all system boundaries where external data enters: API endpoints, webhooks, file uploads, form submissions, message consumers, configuration
- Identify cross-field and conditional validation requirements
- Identify async validation needs: uniqueness checks, external service verification
- Identify sanitization requirements: HTML, SQL, paths, encoding
- Identify file validation requirements: types, sizes, content verification
- Identify configuration validation: environment variables, feature flags, startup checks
- Identify data integrity requirements: checksums, referential integrity, consistency
- Identify pipeline validation: ETL quality gates, schema drift, dead letters
- Identify error format requirements: i18n, field-level errors, client consumption
- Identify performance constraints: validation overhead, async validation latency

Validation architecture workflow:

1. Map all system boundaries where untrusted data enters
2. Define validation schemas for each boundary input
3. Design the validation layer placement within the application architecture
4. Define the error format specification
5. Design cross-field and async validation patterns
6. Define sanitization rules for each data type
7. Design file validation pipeline
8. Define configuration validation for startup and runtime
9. Design contract validation for API evolution
10. Define pipeline validation for data quality gates
11. Map implementation to framework-specific patterns

Input validation at system boundaries:

**API endpoints**: validate all request bodies, query/path/header parameters; parse into typed structures at boundary; enforce size limits; validate pagination bounds.

**Webhooks**: verify signature before parsing; validate against documented schema; handle unknown fields; check timestamp freshness; deduplicate by event ID.

**File uploads**: validate size before reading; verify MIME type from magic bytes (not extension/header); use allowlist; sanitize filenames; validate image dimensions.

**Forms**: validate on client for UX, server for security. Client-side is never a trust boundary — server must re-validate. Prevent duplicates with idempotency tokens.

**Message consumers**: validate schema at boundary; forward-compatible parsing; route unparseable to dead letter queue; log failures with metadata.

Schema-driven validation:

Zod (TypeScript / JavaScript):

- Define schemas as the single source of truth; derive TypeScript types with z.infer
- Use z.object for request bodies; z.string().uuid() for IDs; z.enum for bounded values
- Use z.coerce for query parameters that arrive as strings
- Use z.discriminatedUnion for polymorphic payloads
- Use z.transform for parsing and normalization (trim, lowercase, date parsing)
- Use z.refine and z.superRefine for cross-field and async validation
- Compose schemas with z.extend, z.merge, z.pick, z.omit for DRY contracts
- Keep schemas in dedicated files colocated with the feature they serve

Example:
```typescript
const CreateOrderSchema = z.object({
  customerId: z.string().uuid(),
  items: z.array(z.object({
    productId: z.string().uuid(),
    quantity: z.number().int().positive().max(1000),
  })).min(1).max(100),
  currency: z.enum(['USD', 'EUR', 'GBP']),
  notes: z.string().trim().max(500).optional(),
});
type CreateOrderInput = z.infer<typeof CreateOrderSchema>;
```

**FluentValidation** (.NET): define validators per DTO with RuleFor; use When/Unless for conditionals, MustAsync for async. Keep validators alongside DTOs.

**Joi** (Node.js): define schemas with fluent API; use .when() for conditional, .external() for async. Maintain TypeScript type alignment.

**class-validator** (NestJS): decorate DTO classes with @IsString, @IsUUID, @IsEnum, etc.; use @ValidateIf for conditionals; custom decorators for reusable rules.

**JSON Schema**: language-agnostic contracts for APIs (OpenAPI), config, cross-system. Validate with AJV (JS), JsonSchema.Net (.NET), or jsonschema (Python). Generate TS types with json-schema-to-typescript.

Cross-field validation:

Dependent fields: B required only when A matches value, end date after start date, payment fields conditional on payment method. Implementation: Zod z.refine on parent object; FluentValidation When/Unless; report errors on specific field, not parent. Document rules in schema.

Async validation scenarios: uniqueness checks, external service verification (address/payment), CAPTCHA, reference validation. Rules: async runs after sync passes; cache results; set timeouts; handle unavailability gracefully; rate-limit endpoints.

Data sanitization:

By type: strings (trim, normalize unicode, limit length), HTML (allowlist sanitization with DOMPurify), SQL (parameterized queries only), paths (reject ../), URLs (https only, no javascript: scheme), email (normalize, validate), phone (E.164), JSON (size/nesting limits).

Encoding: context-specific (HTML entities, URL encoding, JSON). Never rely on input sanitization alone — always encode on output using framework utilities.

Placement: sanitize at boundary after validation; store sanitized version; document applied guarantees.

Validation error formatting:

Error response structure:

```json
{
  "type": "validation_error",
  "message": "Validation failed",
  "errors": [
    {
      "field": "items[0].quantity",
      "code": "too_large",
      "message": "Quantity must not exceed 1000",
      "params": { "max": 1000, "actual": 5000 }
    },
    {
      "field": "currency",
      "code": "invalid_enum",
      "message": "Currency must be one of: USD, EUR, GBP",
      "params": { "allowed": ["USD", "EUR", "GBP"], "actual": "BTC" }
    }
  ]
}
```

Error format rules:

- Use a consistent error shape across all endpoints and services
- Include field path with array index notation for nested errors
- Use machine-readable error codes (too_large, required, invalid_format), not just messages
- Include parameters that caused the failure for client-side message construction
- Support i18n: clients build human-readable messages from code + params, not from the message field
- HTTP status: 400 for validation errors, 422 for semantically correct but unprocessable requests
- Never expose internal error details, stack traces, or implementation specifics

Framework integration:

.NET: Use a middleware or filter to catch ValidationException and format consistently
NestJS: Use a global exception filter to catch class-validator errors and format
Elysia/Bun: Use onError hook to catch Zod errors and format
Express: Use error-handling middleware to catch and format validation errors

Contract validation:

API responses: validate in dev/staging to catch drift early; use schema tests; version schemas; detect breaking changes in CI. Schema evolution: additive changes (new optional) are safe; removing/changing types requires versioning and backward-compat validation in CI.

Contract testing: consumer-driven (Pact, Schema Registry) for service boundaries; provider verifies contracts before deploy; keep tests in CI.

Database constraints vs application: constraints handle NOT NULL, UNIQUE, CHECK, foreign keys; application handles format (email/URL/phone), cross-field rules, auth checks, external service validation. Both layers needed: database is last-line defense, application provides UX and prevents DB round-trips. Constraints document schema invariants.

File validation:

Pipeline: 1) size check before reading, 2) extension allowlist, 3) magic bytes (FF D8 FF for JPEG, 89 50 4E 47 for PNG, 25 50 44 46 for PDF, etc.), 4) derive MIME from bytes not header, 5) content checks (image dimensions, PDF pages), 6) sanitize metadata, 7) malware scan if risk-based. Use file-type (Node.js) or custom magic byte checks (.NET); never trust extension alone.

Configuration validation:

Environment variables: validate all required at startup; fail fast with clear messages; type-parse (numbers, booleans, URLs, durations). Use Zod or framework-specific validation (AddOptions with ValidateDataAnnotations in .NET). Feature flags: type-check at startup (boolean, string, number, JSON); log active flags; fail on invalid config, never silent defaults.

Data integrity:

Checksums (SHA-256) for file integrity; verify after migration/import. ETags for cache validation and optimistic concurrency. Referential integrity: enforce foreign keys in DB; validate existence at application level for cross-service refs; handle orphans gracefully. Cross-system: reconciliation queries for duplicate data; periodic checks on critical data; alert on drift.

Pipeline validation:

ETL data quality: validate schema before processing (columns, types, required); check data quality (null rates, distributions, outliers); fail on violations; log rejections. Schema drift: detect new/removed columns, type changes; alert on drift; auto-adapt for additive. Events/messages: validate schema at consumer; version and maintain backward compat; route invalid to dead letter queue; monitor DLQ depth; retry with backoff for transient failures.

Anti-patterns: validating deep in logic instead of boundaries; client-side only; silently catching errors; string matching instead of schemas; trusting extensions/headers for files; concatenating user input into SQL/HTML/shell; exposing internal errors in responses; redundant validation; custom validation when library exists; skipping database constraints.

Implementation: translate architecture to concrete schemas, middleware, config. Specify validation library per layer/framework. Provide critical boundary examples. Define error format, layer placement, cross-field/async patterns, sanitization rules, file/config/contract validation, and DB constraint split.
