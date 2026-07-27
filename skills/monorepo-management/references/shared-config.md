# Shared configuration

Share configuration only where packages have the same contract. Inspect installed compiler, linter, formatter, test/build tooling, module system, package exports and deployment targets; use their local schema/types and matching official docs for exact syntax.

- Prefer an explicit base plus small platform/package overlays. A frontend, Node service, library, native package and generated client may require different module, target, DOM, JSX, declaration or test settings.
- Package shared config with clear ownership and versioning when consumers need independent upgrades; use root files only when the repository release boundary makes that coupling intentional.
- Include shared config and its transitive inputs in task/cache keys. Generated config needs a source of truth and drift check.
- Avoid path aliases that work only in the editor while bypassing package exports or runtime resolution. Verify compiler, test runner, bundler and published consumer behavior together.
- Do not centralize dependency versions or style rules solely for uniformity. Preserve justified package-specific constraints and document exceptions close to their owner.

Verify representative packages for every platform, clean build and published/packed consumption where relevant, editor/CLI parity, cache invalidation, mixed config versions during migration, generated-file drift and rollback.
