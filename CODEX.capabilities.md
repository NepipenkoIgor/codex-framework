# AI Codex Capability Model

This framework treats runtime tools as capabilities, not as hard-coded plugins.

## Why

Claude plugins bundle tools, settings, and hooks into one runtime model.
Codex is more environment-driven: tools may or may not exist in the current session.

To stay efficient, the framework must know:

- what the project likely needs
- what the runtime actually provides
- what local fallback commands are runnable even without structured tools
- what auth is configured versus fully validated
- what fallback path to use when a capability is missing

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

### Platform Integrations

- `supabase-tools`
- `firebase-tools`
- `stripe-tools`

## Resolution Rules

For each task, the framework should determine:

1. desired capabilities from stack and task intent
2. available capabilities from the live environment
3. preferred tool path
4. fallback tool path

## GitHub Capability Contract

For GitHub-driven work:

- Preferred: `github-structured`
- Fallback: `github-cli` with `github-auth`
- Last fallback: local `git` only

`github-auth` should distinguish:

- configured
- validated
- unavailable

Task briefs should state all three clearly.

## Diagnostics Capability Contract

- Preferred: live diagnostics tools
- Fallback: project-native commands such as `tsc`, `dotnet build`, linters, tests

## Browser Capability Contract

- Preferred: browser automation tools
- Fallback: manual verification, screenshots supplied by the user, or code-only review

## Framework Rule

The framework must never assume a capability exists just because the project stack suggests it should be useful.
Detection and fallback are part of the operating model.
