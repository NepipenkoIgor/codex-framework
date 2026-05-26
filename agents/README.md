# Role Briefs

These files are Codex role briefs. Runtime named-agent behavior is defined by `registry.tsv`.

They are not new native Codex `agent_type` values by themselves. Use them as:

- delegation templates for `spawn_agent`
- reference documents for task routing
- maintenance artifacts for the framework

Keep wording explicit: a skill is loaded as instruction context, a named agent is the active or delegated framework role, and a sub-agent exists only after explicit spawn/delegation. Do not describe `skills/*/SKILL.md` entries as agents.

`registry.tsv` maps names such as `builder-backend`, `reviewer`, and `tester` to Codex runtime spawn types:

- `worker` for editing, testing, fixing, and implementation
- `explorer` for read-only review, audit, discovery, and estimation
- `default` for coordination or planning

Use `codex-fw agent list`, `codex-fw agent get <agent>`, `codex-fw agent prompt <agent> --task "<task>"`, and `codex-fw agent validate`.

The core roles were rewritten for Codex first. Remaining files copied from `ai-skills` are available as source material and should be normalized as the framework evolves.

The intent is senior-engineer behavior inside each domain: broad enough to understand the framework, the release path, security, docs, and performance, while still remaining role-specific.

Specialized implementation routes now include:

- `builder-mobile`
- `builder-fullstack`
- `builder-automation`
- `builder-ai`
- `builder-n8n`
