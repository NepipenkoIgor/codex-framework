---
name: database-migration
description: Design and implement database migrations, schema changes, seed data, and rollback strategies
metadata:
  version: 1.6
  argument-hint: "schema changes, new columns/tables, data transformations, rollback plans"
---

Design and implement database migrations for $ARGUMENTS.

## Documentation

> Use available docs lookup tools or official docs when you encounter unknown API syntax, current library versions, or framework-specific configuration. Do not rely on training data for library docs — fetch current docs on demand.

Tooling in scope:
- .NET: EF Core Migrations, FluentMigrator, raw SQL scripts
- Node.js/TypeScript: Prisma Migrate, TypeORM Migrations, Knex, raw SQL scripts
- Databases: PostgreSQL, SQL Server, MySQL, SQLite

Migration workflow:

1. Identify the schema change and its impact scope
2. Classify the change: additive, breaking, data-only, or mixed
3. Design the migration with forward safety and rollback path
4. Define index strategy for new or modified columns
5. Plan data backfill if existing data must change
6. Verify zero-downtime compatibility for live systems
7. Write the migration code; define rollback procedure
8. Specify CI verification steps

Migration immutability — CRITICAL:

- NEVER modify, edit, or update an existing migration file — always create a new migration
- This applies to ALL databases and ORMs: Supabase, Prisma, EF Core, TypeORM, Knex, Drizzle, raw SQL, any other
- If a previous migration was wrong, create a corrective migration that undoes/fixes the issue
- If a migration hasn't been applied anywhere yet and the user explicitly asks to replace it, only then delete and recreate
- Modifying applied migrations causes checksum mismatches, deployment failures, and data corruption

Migration strategy:

- Forward-only for production; up/down for development convenience
- Every migration must be idempotent or guarded against re-execution
- One logical change per migration; never combine schema and data changes
- Name descriptively: AddInvoiceStatusColumn, CreateUserPreferencesTable

Schema design principles:

- Explicit primary keys; UUID/ULID for distributed, integer for simple systems
- NOT NULL by default; nullable only when business logic requires absence
- Foreign keys with explicit ON DELETE (CASCADE, SET NULL, RESTRICT)
- Check constraints for enums and bounded values; unique constraints for business uniqueness
- Created/updated timestamps on every mutable table
- Soft delete (deleted_at) when business requires recoverability

Index strategy:

- Index every foreign key column and columns in WHERE, ORDER BY, JOIN
- Composite indexes: most selective column first; match query patterns
- Partial indexes for filtered queries (WHERE status = 'active')
- Unique indexes for business constraints at database level
- Avoid over-indexing; each index has write overhead
- PostgreSQL: CREATE INDEX CONCURRENTLY; SQL Server: WITH (ONLINE = ON)

Zero-downtime migration patterns:

Expand-contract:
1. Expand: add new column/table; make nullable or with default
2. Migrate: backfill data; deploy code reading both old and new
3. Contract: remove old structure after all code uses new

Column rename/type change: add new, backfill, update code, drop old

Never in a single deploy:
- Drop a column that running code reads
- Rename without expand-contract
- Add NOT NULL without default to populated table
- Drop an index that active queries use

Data migration patterns:

- Backfill in batches of 1000-5000 rows; commit per batch; log progress
- Cursor-based iteration for large tables; avoid OFFSET for millions of rows
- Run data migrations as separate scripts, not inside schema migrations
- Verify integrity after backfill with COUNT, checksums, or sample queries

.NET EF Core migrations:

```csharp
public partial class AddInvoiceStatusColumn : Migration
{
    protected override void Up(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.AddColumn<string>(
            name: "Status", table: "Invoices",
            type: "varchar(20)", nullable: false, defaultValue: "draft");
    }

    protected override void Down(MigrationBuilder migrationBuilder)
    {
        migrationBuilder.DropColumn(name: "Status", table: "Invoices");
    }
}
```

- Keep DbContext and entity configuration aligned with migrations
- Use migrationBuilder.Sql() for raw SQL when EF builder is insufficient
- Never modify a migration applied to any shared environment

TypeORM migrations:

```typescript
export class AddInvoiceStatusColumn implements MigrationInterface {
    async up(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`
            ALTER TABLE "invoices"
            ADD COLUMN "status" varchar(20) NOT NULL DEFAULT 'draft'
        `);
    }
    async down(queryRunner: QueryRunner): Promise<void> {
        await queryRunner.query(`ALTER TABLE "invoices" DROP COLUMN "status"`);
    }
}
```

Prisma migrations:

- Generate: npx prisma migrate dev --name add_invoice_status
- Review generated SQL in prisma/migrations/ before applying
- Production: prisma migrate deploy; never prisma migrate dev

Seed data management:

- Separate categories: dev seeds, staging data, production reference data
- Production seeds: enums, roles, permissions, system config, reference codes
- Make seeds idempotent: upsert or check-before-insert
- Version seeds alongside migrations; never put test data in production seeds
- EF Core 9+: prefer `UseSeeding`/`UseAsyncSeeding` on `DbContext` over `HasData` for production seeds with complex initialization (relationships, conditional logic, external dependencies)

Rollback strategies:

- Every migration must have a documented rollback path
- Down migrations for schema; reverse scripts for data changes
- Feature flags to toggle old/new code paths during migration
- For irreversible changes: backup before execution; test rollback in staging

Foreign key and constraint management:

- Add foreign keys in migrations; do not rely on application-level enforcement
- Add constraints after backfill on existing tables with data
- Validate existing data before adding NOT NULL or CHECK constraints

Migration testing and CI:

- Run migrations from empty to current in CI
- Run against production-like schema snapshot
- Verify both up and down execute without errors
- Fail CI on migration order conflicts

Multi-tenant considerations:

- Shared database: tenant column on every scoped table; include in indexes
- Schema-per-tenant: apply migrations to all schemas; handle ordering
- Database-per-tenant: orchestrate across all databases

Migration ordering:

- Chronological order; never reorder applied migrations
- Rebase and regenerate on merge conflicts; never manually edit timestamps
- Document cross-service dependencies when services share a database

Output requirements:

- Start with a short migration summary
- Classify the change type (additive, breaking, data-only, mixed)
- Provide migration code or SQL for both up and down
- Define index strategy for affected tables
- Specify data migration approach if backfill is needed
- Document zero-downtime steps if applicable
- Include rollback procedure

## Structured Output Contract
- **Status**: `done` | `partial` | `blocked`
- **Changed**: `[file.ext: +lines/-lines, ...]` — list every modified file
- **Notes**: blockers or non-obvious decisions only — omit if none

Do NOT return prose summaries or recaps.
