# AI Codex Capability Model

This framework treats runtime tools as capabilities, not as hard-coded plugins.

## Why

Claude plugins bundle tools, settings, and hooks into one runtime model.
Codex is more environment-driven: tools may or may not exist in the current session.

To stay efficient, the framework must know:

- what the project likely needs
- what the runtime actually provides
- what auth is configured versus fully validated
- what runtime path to use for each capability

## Capability Categories

### Source Control And Collaboration

- `git`
- `github-cli`
- `github-auth`
- `github-structured`

### Diagnostics

- `ts-diagnostics`
- `csharp-diagnostics`

### Browser And Visual

- `browser-automation`

### Codex Runtime Lifecycle

- `codex-hooks`

### Platform Integrations

- `supabase-tools`
- `firebase-tools`
- `stripe-tools`

## Resolution Rules

For each task, the framework should determine:

1. desired capabilities from stack and task intent
2. available capabilities from the live environment
3. preferred tool path
4. required runtime checks before use

## GitHub Capability Contract

For GitHub-driven work:

- Preferred: `github-structured`
- Secondary path: `github-cli` with `github-auth`
- Local path: `git` only

`github-auth` should distinguish:

- configured
- validated
- unavailable

Task briefs should state all three clearly.

## Diagnostics Capability Contract

- Preferred: live diagnostics tools
- Project-native path: commands such as `tsc`, `dotnet build`, linters, tests

## Browser Capability Contract

- Preferred: browser automation tools
- Manual path: human verification, screenshots supplied by the user, or code-only review

## Hook Capability Contract

- Required: Codex runtime hooks configured as inline TOML blocks in `.codex/config.toml`; `.codex/hooks.json` may exist as a generated adapter artifact.

Hooks are adapters only. They call framework scripts for context, routing, guard checks, change tracking, and memory recording.
If hook config is missing, fix hook installation instead of switching Desktop lifecycle work to manual commands.

## Framework Rule

The framework must never assume a capability exists just because the project stack suggests it should be useful.
Detection and required runtime wiring are part of the operating model.
