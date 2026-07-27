# Dynamic version context

The framework does not store a "current version" matrix. `skills/version-sources.tsv` stores only release tracks, resolver types, official documentation, and action templates. `scripts/framework-stack-context.py` resolves release data or inspects a project when the task runs; its output is ephemeral and must not be committed as framework state.

## Existing projects

Inspect the repository before applying version-sensitive guidance:

```bash
${CODEX_HOME:-$HOME/.codex}/bin/codex-framework-stack-context project /path/to/project --format markdown
```

The resolver reads manifests, lockfiles, runtime files, and installed package metadata where available. Preserve those pins for ordinary work. Upgrading is a separate migration with compatibility review, tests, rollback criteria, and documentation for the installed line.

## New projects

Resolve only the stack needed for the task:

```bash
${CODEX_HOME:-$HOME/.codex}/bin/codex-framework-stack-context latest nextjs react nodejs typescript --format markdown
${CODEX_HOME:-$HOME/.codex}/bin/codex-framework-stack-context action expo
```

Then:

1. Use the emitted vendor scaffold or stable/LTS action.
2. Inspect the generated manifest and lockfile; they become the project's source of truth.
3. Check runtime/compiler/framework compatibility as a unit. Resolver metadata includes npm engine and peer ranges when vendors publish them.
4. Apply a recipe only when the generated or installed stack exposes its capability. Check package types, CLI help, configuration schema, or matching official documentation instead of branching on a version remembered by a skill.
5. Record the selected versions and sources in the task handoff. Do not select prerelease channels unless requested.

`latest` protects release selection, not semantic compatibility. Breaking changes still require one update to the relevant capability rule or reference, but routine release bumps do not require editing every skill.

## Governance

```bash
bash scripts/framework-version-drift-check.sh
bash scripts/framework-version-drift-check.sh --self-test
bash scripts/framework-version-drift-check.sh --live
```

Offline checks validate the resolver contract and reject numeric versions embedded in scaffold guidance. The live check exercises distribution resolvers and prints the current context; it never compares against a tracked snapshot or creates a refresh deadline.
