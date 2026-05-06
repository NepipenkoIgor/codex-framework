#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

failures=0
checks=0

check_file_has() {
  local file="$1"
  local label="$2"
  local pattern="$3"
  checks=$((checks + 1))
  if grep -Eiq "$pattern" "$ROOT/$file"; then
    printf 'ok %02d %-42s %s\n' "$checks" "$label" "$file"
  else
    printf 'not ok %02d %-38s missing /%s/ in %s\n' "$checks" "$label" "$pattern" "$file"
    failures=$((failures + 1))
  fi
}

check_role_has_skill() {
  local role="$1"
  local skill="$2"
  checks=$((checks + 1))
  if grep -Eq "^[[:space:]]+- ${skill}$" "$ROOT/agents/$role.md"; then
    printf 'ok %02d role %-29s has %s\n' "$checks" "$role" "$skill"
  else
    printf 'not ok %02d role %-25s missing %s\n' "$checks" "$role" "$skill"
    failures=$((failures + 1))
  fi
}

check_file_has "skills/frontend-implement/SKILL.md" "frontend follows repo patterns" "existing conventions|current codebase"
check_file_has "skills/frontend-implement/SKILL.md" "frontend design system reuse" "design system|component patterns|tokens"
check_file_has "skills/frontend-implement/SKILL.md" "frontend utility class policy" "utility classes|inline styles|className|tokens"
check_file_has "skills/frontend-implement/SKILL.md" "frontend async states" "loading, error, empty"
check_file_has "skills/frontend-implement/SKILL.md" "frontend accessibility" "accessibility|semantic HTML|ARIA"
check_file_has "skills/frontend-implement/SKILL.md" "frontend responsive" "responsive|breakpoint|viewport"
check_file_has "skills/frontend-implement/SKILL.md" "frontend performance" "performance|re-render|memoization|waterfall"
check_file_has "skills/frontend-implement/SKILL.md" "frontend dry" "duplication|duplicate|DRY|reuse"
check_file_has "skills/frontend-implement/SKILL.md" "frontend kiss" "simple|focused|KISS|over-engineering"

check_file_has "skills/frontend-review/SKILL.md" "frontend review UI consistency" "UI consistency|design system|tokens"
check_file_has "skills/frontend-review/SKILL.md" "frontend review styling policy" "inline styles|utility classes|hardcoded"
check_file_has "skills/frontend-review/SKILL.md" "frontend review accessibility" "accessibility"
check_file_has "skills/frontend-review/SKILL.md" "frontend review performance" "performance"

check_file_has "skills/design-system-implement/SKILL.md" "design system tokens" "tokens"
check_file_has "skills/design-system-implement/SKILL.md" "design system variants" "variants|cva|class-variance"
check_file_has "skills/ui-consistency-audit/SKILL.md" "ui audit hardcoded values" "Hardcoded Colors|hardcoded"
check_file_has "skills/ui-consistency-audit/SKILL.md" "ui audit component matrix" "Component Matrix"

check_file_has "skills/backend-implement/SKILL.md" "backend boundary validation" "Validate inputs|boundary"
check_file_has "skills/backend-implement/SKILL.md" "backend contract separation" "request|response|contracts|DTO"
check_file_has "skills/backend-implement/SKILL.md" "backend persistence separation" "persistence|transaction|query"
check_file_has "skills/backend-implement/SKILL.md" "backend no hardcode policy" "hardcoded|configuration|environment"
check_file_has "skills/backend-implement/SKILL.md" "backend security" "security|auth|sensitive"
check_file_has "skills/backend-implement/SKILL.md" "backend observability" "observability|logging|telemetry"
check_file_has "skills/backend-implement/SKILL.md" "backend performance" "performance|query|I/O|N\\+1"
check_file_has "skills/backend-implement/SKILL.md" "backend dry" "duplicated|duplicate|DRY|reuse"
check_file_has "skills/backend-implement/SKILL.md" "backend kiss" "minimum viable|unnecessary abstraction|over-engineering|smallest"

check_file_has "skills/backend-review/SKILL.md" "backend review DB consistency" "database|migration|query|transaction"
check_file_has "skills/backend-review/SKILL.md" "backend review hardcode" "hardcoded|configuration|secret"
check_file_has "skills/backend-review/SKILL.md" "backend review contracts" "contract"
check_file_has "skills/backend-review/SKILL.md" "backend review performance" "performance"

check_file_has "skills/data-modeling/SKILL.md" "data modeling constraints" "foreign key|constraint|unique"
check_file_has "skills/database-migration/SKILL.md" "migration immutability" "NEVER modify|existing migration"
check_file_has "skills/database-migration/SKILL.md" "migration ledger check" "schema_migrations|_prisma_migrations|__EFMigrationsHistory|knex_migrations|__drizzle_migrations"
check_file_has "skills/database-optimization/SKILL.md" "db optimization N+1" "N\\+1"
check_file_has "skills/performance/SKILL.md" "performance measurement first" "Measure before optimizing|Profile"
check_file_has "skills/code-reuse/SKILL.md" "code reuse over abstraction" "over-abstracting|over-abstract|Extract only"

check_role_has_skill "builder-frontend" "design-system-implement"
check_role_has_skill "builder-frontend" "ui-consistency-audit"
check_role_has_skill "builder-frontend" "responsive-design"
check_role_has_skill "builder-frontend" "accessibility-implement"
check_role_has_skill "builder-backend" "data-validation-design"
check_role_has_skill "builder-backend" "database-migration"
check_role_has_skill "builder-backend" "database-optimization"
check_role_has_skill "builder-backend" "auth-security"
check_role_has_skill "builder-backend" "observability-design"
check_role_has_skill "reviewer" "ui-consistency-audit"
check_role_has_skill "reviewer" "security-audit"
check_role_has_skill "reviewer" "performance"
check_role_has_skill "architect" "data-modeling"
check_role_has_skill "architect" "database-migration"
check_role_has_skill "architect" "design-system-architecture"
check_role_has_skill "refactorer" "code-reuse"
check_role_has_skill "fixer" "performance"

printf 'skill quality audit: %d checks, %d failures\n' "$checks" "$failures"

if [ "$failures" -ne 0 ]; then
  exit 1
fi
