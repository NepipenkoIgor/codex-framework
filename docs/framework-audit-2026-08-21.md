# Native Codex framework audit — 2026-08-21

## Outcome

The framework now adopts the native task topology shipped through Codex CLI 0.149.0 without adding orchestration wrappers. The active Bun-managed CLI was upgraded from 0.147.0 to 0.149.0. Desktop already exposes native thread forking; CLI now exposes `codex exec fork`, `codex agents`, and `codex queue`.

| Dimension | Score | Evidence | Residual risk |
| --- | ---: | --- | --- |
| Native ownership | 10/10 | `templates/global/AGENTS.md`, `README.md`, no task registry, queue, fork, plan, or lifecycle wrapper | Native surfaces differ between Desktop and CLI, so exact callable behavior still requires live discovery |
| Routing | 9/10 | Fork/new-task/subagent boundaries are explicit and positive/negative deterministic contract cases cover them | Natural-language routing quality still depends on the active model and current task context |
| Skill design | 9/10 | One core skill, native catalog discovery, no prompt injector or skill router | Catalog pressure can change as installed skills grow; keep prompt-input evidence live |
| Coordination | 10/10 | History-backed fork, independent task, bounded subagent, completed-history, and separate-worktree rules are distinct | Same-directory forks remain unsafe for concurrent writers and are intentionally not automatic |
| Verification | 8/10 | Live official-source fingerprints, static and semantic counterexample checks, native CLI help, framework health, doctor without evidence, loader canary, and live routing passed | Digest-bound release certification is pending a fresh committed-source corpus run |
| Runtime safety | 9/10 | Effective profile verification after fork/resume; one synchronous local safety hook; no async or MCP side effects in hooks | An invalid persisted profile can resolve to the configured default, so consequential continuation must fail closed on mismatch |
| Maintainability | 9/10 | 0.148.0 and 0.149.0 decisions are recorded in the capability ledger with repository evidence | Official manual/changelog fingerprints intentionally invalidate on any upstream content change |

## Release delta reviewed

### Codex CLI 0.148.0

- Adopted native session forking through `codex exec fork`; no wrapper was added.
- Retained native archive and restore ownership; no local session index was added.
- Retained the framework's synchronous local safety hook despite native async and MCP hook support. Hidden background work or external side effects do not belong in the framework hook lifecycle.
- Adopted native restoration of persisted working directory and permission state without adding an override. Because an invalid persisted profile can resolve to the configured default, the effective directory and profile must be verified before consequential continuation.
- Kept complete conversation export through `/export` permission-gated; the framework never exports task history automatically.

### Codex CLI 0.149.0 and August 20 product updates

- Adopted `codex agents` and `codex queue` as native task discovery and messaging surfaces; local task dashboards and queues remain prohibited.
- Adopted expanded `codex doctor` diagnostics. `framework-doctor.sh` continues to delegate platform checks to native doctor and adds only framework-specific installation and evidence checks.
- Retained the native skill-catalog budget because live prompt-input validation shows complete core discovery without truncation; no prompt injector or router was introduced.
- Confirmed resumed and forked threads normally restore the active permission profile. If persisted profile state is invalid, configured-default resolution remains possible and must surface as a stop-and-resolve mismatch before consequential work.
- Kept read-only shared thread snapshots permission-gated because sharing can expose sensitive task history even after native secret-pattern redaction.
- The new `/cd`, `/pwd`, `/cwd`, Vim motions, SDK config overrides, and reasoning levels require no framework layer. Existing projects remain repository/manifest-first, and model or permission selection stays native.

## Automatic selection contract

- Fork: an explicitly requested alternative that needs the source task's completed history.
- New task: explicitly requested work that should not inherit task history.
- Subagent: bounded work that remains part of the current request and parent-owned integration.
- Worktree: required isolation for parallel writers, including forked user-visible tasks.
- Native task message or queue: steering an existing task; never a local queue file or polling loop.

Forking does not copy an active unfinished turn. A same-directory fork is therefore not an automatic handoff and must not be used for concurrent writes.

## Deliberately not automated

- Plugin installation, trust, connector authorization, shared-thread publication, Auto-review, Browser/CDP approval, Computer Use, and Record & Replay remain user or workspace gates.
- Async and MCP hooks are not used for routing, retries, task control, or external mutations.
- The framework does not change models, reasoning effort, permission profiles, or working directories after a fork. It verifies the effective directory and profile before consequential continuation.

## Activation boundary

The active CLI and framework installation are verified on 0.149.0. Digest-bound release certification is pending because the current source is uncommitted and the prior evidence is bound to 0.147.0 and the previous source digest. The global working agreement is a symlink to this checkout, but a new task is still the reliable instruction reload boundary. Desktop application-level configuration changes would require a restart; this audit did not change Desktop settings.
