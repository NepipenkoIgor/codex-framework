# Package boundary enforcement

Select the smallest mechanism already compatible with the repository: workspace exports, language/compiler project references, linter import restrictions, an installed graph tool, or the orchestrator's native boundary rules. Verify exact syntax against installed schemas and CLI help.

- Derive allowed dependency directions from actual package ownership, runtime/platform boundaries and public contracts. Do not impose a generic `apps/features/shared` taxonomy.
- Enforce package public entrypoints and prevent deep/private imports where the package contract requires it. Keep generated code and test-only dependencies explicit.
- Detect cycles, but classify them: runtime cycles, type-only edges, generated artifacts and test fixtures have different consequences. Extraction is one option, not an automatic response.
- Roll out new rules against the current graph first. Inventory violations, distinguish intended exceptions, migrate incrementally, and prevent a broad suppressions file from becoming the real policy.
- A generator is separate from enforcement. Add one only for a stable repeated contract and test its validation, collisions, idempotency and output.

Verify allowed and forbidden fixture imports, path aliases/exports, cross-platform packages, type-only/test/generated edges, cycles, editor and CI parity, incremental adoption and rollback of the rule configuration.
