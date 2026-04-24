# CODEX.permissions.md

Codex permissions are runtime-controlled. This framework can reduce friction, but it cannot self-grant broader access than the active environment allows unless the local Codex launcher starts with a broader runtime profile.

## Framework Default Runtime Profile

After running `scripts/setup.sh`, the shell wrapper exports:

- `CODEX_APPROVAL_MODE="never"`
- `CODEX_SANDBOX_MODE="danger-full-access"`

That makes the wrapped `codex` command behave like:

- `codex -a never -s danger-full-access`

Use `codex --raw` to bypass the wrapper and open plain Codex with no framework defaults.

If you want a stricter profile in one shell:

- `export CODEX_APPROVAL_MODE=on-request`
- `export CODEX_SANDBOX_MODE=workspace-write`
- `unset CODEX_FULL_AUTO`

## What The Framework Can Do

- avoid protected write paths when `/tmp` fallbacks are available
- keep generated artifacts under writable roots
- prefer explicit local scripts over ad hoc shell commands
- install repo-local git hooks when the runtime allows local git config writes
- recommend reusable approval prefixes for common framework workflows
- set a default Codex launcher profile through the shell wrapper

## What The Framework Cannot Do

- grant global shell access on its own
- disable the runtime sandbox
- force network access when the session is network-restricted
- bypass approval prompts for commands outside approved prefixes
- change the behavior of an already running Codex session

## Low-Friction Working Style

Prefer framework commands first:

- `codex-fw doctor`
- `codex-fw preflight`
- `codex-fw brief "<task>"`
- `codex-fw plan "<task>"`
- `codex-fw post-change-check`
- `codex-fw guard-scan --changed`
- `codex-fw work <issue>`

These commands are designed to stay inside the framework’s writable paths and avoid unnecessary ad hoc shell work.

## Approval Categories

### Usually no extra approval

- reads inside the workspace
- writes inside writable roots
- framework cache and run artifacts under writable locations
- local script execution that stays within the workspace

### Often triggers approval

- `git config --local` or anything that locks `.git/config`
- networked package installs or downloads
- browser/GUI launches
- writes outside workspace writable roots
- new shell commands outside established framework paths

## Recommended Reusable Prefixes

If your runtime supports persistent prefix approvals, these are reasonable candidates:

- `["bash", "scripts/framework-health.sh"]`
- `["bash", "scripts/doctor.sh"]`
- `["bash", "scripts/post-change-check.sh"]`
- `["bash", "scripts/guard-scan.sh"]`
- `["bash", "scripts/codex-fw.sh", "doctor"]`
- `["bash", "scripts/codex-fw.sh", "brief"]`
- `["bash", "scripts/codex-fw.sh", "plan"]`
- `["bash", "scripts/codex-fw.sh", "post-change-check"]`
- `["bash", "scripts/codex-fw.sh", "guard-scan"]`
- `["git", "config", "--local"]` only if you want hook setup without repeated prompts

Keep approvals narrow. Do not try to recreate Claude-style broad `Bash(*)` access through the framework.

## Practical Goal

The framework should make approvals:

- rarer
- more predictable
- attached to stable command prefixes
- easier to accept once and reuse

That is the Codex-native replacement for Claude’s broader permission presets.
