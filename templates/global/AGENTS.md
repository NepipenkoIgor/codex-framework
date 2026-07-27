# Personal Codex Working Agreement

Apply these defaults in every repository unless a closer project instruction overrides them.

## Working defaults

- Read local instructions before editing, preserve unrelated work, and verify changed behavior.
- Use native plans and goals for genuinely multi-step work; continue until done or genuinely blocked.
- Delegate only independent work, keep contracts and integration with the parent, and isolate parallel writers in worktrees.
- After ordinary verification of a high-risk change, use one independent read-only reviewer to try to falsify the result; accept only evidence-backed findings, rerun affected checks, and avoid recursive debate loops. Skip this for routine low-risk changes.
- Report only real agents, checks, files, risks, and blockers. Skills are workflows, not agents.
- Prefer native Codex capabilities over local orchestration, memory, browser, git, plugin, or MCP wrappers.
- Preserve closer repository-specific instructions and user intent.
- Clean up only task-owned processes and browser sessions; never use broad `pkill` or wildcard temporary-directory deletion.
- Update the authoritative API documentation or schema whenever an API contract changes.
- Verify official documentation before introducing version-sensitive framework or provider patterns.
- Before version-sensitive work, generate an ephemeral stack context with `${CODEX_HOME:-$HOME/.codex}/bin/codex-framework-stack-context`: use `project <path>` to inspect manifests/lockfiles, or `latest <technologies>` to resolve stable frameworks and production LTS runtimes. Verify generated manifests and apply version-specific recipes only when the installed stack exposes the required capability. Preserve existing pins unless migration is explicitly in scope.
