# AI Codex Framework

A thin, native Codex extension layer for reusable engineering skills, project instructions, focused subagent profiles, native approval rules and automatic evidence-based challenge.

## Native ownership

Codex owns planning, models, skill selection, approvals, sandboxing, worktrees, plugins, MCP, browser control, native agent messaging, and agent orchestration. This repository does not ship shell routers, prompt gates, context injection, model fallback chains, issue/PR wrappers, synthetic agent workflows, or local conversation-memory engines.

## Automatic project understanding

Open a project and give Codex a task. The global agreement asks it to discover the minimum project map from existing code, manifests, scripts, CI and docs; no manually prepared AGENTS.md is required. Later tasks inspect changed and affected areas, deepen understanding during work, and update useful verified contracts/docs/tests within scope. External identity and authority are revalidated before consequential actions. No discovery daemon, mandatory generated brief, context cache or automatic memory write is added. See [project understanding](docs/project-understanding.md).

## Install

Use Python 3.11+ as `python3` for framework checks; setup and doctor diagnose an older interpreter before using it. Ordinary installation must run from a clean detached Git checkout at the intended reviewed commit. Setup creates an independent durable clone under `${CODEX_HOME:-$HOME/.codex}/frameworks/releases/<SHA>`; installed links survive removal of the source worktree. Keep development in a separate worktree; never edit or sweep installed release clones as temporary work.

```bash
git worktree add --detach /path/to/framework-install-source <reviewed-commit>
bash /path/to/framework-install-source/scripts/setup.sh
git worktree remove /path/to/framework-install-source
```

For deliberate local framework development only, `bash scripts/setup.sh --development` permits mutable source links. This is an explicit opt-in, not a stable release. Setup records source SHA, detached/branch state and content digest; doctor reports source drift, including changes between two dirty states. Source identity does not certify release checks or prove a running task has reloaded instructions. To roll back, run setup from the previous clean detached checkout; only recorded managed resources may be replaced.

Start a new Codex session after installation. Codex discovers the installed skills and agents directly. Plugin lifecycle belongs to native `codex plugin` commands and the repository marketplace; setup installs only the intentionally minimal universal core, profiles, and project safety surfaces that plugins do not own.

To use the opt-in frontend plugin, let Codex own marketplace registration and installation:

```bash
codex plugin marketplace add /path/to/codex-framework
codex plugin add codex-frontend-design@ai-codex-framework
```

The installer uses the canonical native USER skill location, `~/.agents/skills`, and records only the skill, profile, rule, binary, and framework links it creates. It migrates old namespaced `~/.codex/skills/codex-framework-*` links after a zero-write collision preflight. User-owned files, unrecorded same-target symlinks, symlinked legacy namespaces, and replaced managed links are never adopted, overwritten, or traversed.

Install opt-in domain packs explicitly:

```bash
bash ~/.codex/frameworks/codex-framework/scripts/setup.sh --pack frontend --pack fullstack
```

Available pack names are discovered from `skills/packs/*.txt`; current domains include `engineering`, `frontend`, `backend`, `fullstack`, `mobile`, `ai`, `automation`, `infra`, and `product`. Every non-core local skill has exactly one owning pack and is not loaded globally by default.

To add the framework to a project without overwriting its existing instructions:

```bash
bash scripts/bootstrap-project.sh /path/to/project
```

This creates `AGENTS.md`, project-scoped profiles in `.codex/agents/`, native safety rules and `.codex/skill-packs.txt`. Add one pack name per line, then run:

```bash
bash scripts/framework-skill-sync.sh /path/to/project
```

Project packs become direct native REPO skills under `.agents/skills`. Framework ownership is stored outside the worktree in Git metadata, so team-owned skills can coexist and collisions fail before any write.

## Project context and environment authority

The global and project instruction templates require a compact project contract before non-trivial work: repository shape, manifest/lockfile-owned stack, authoritative commands, environment map, and release or mutation boundaries. Before a database, deployment, provider, authentication, or other environment-dependent action, Codex must resolve the exact target and its authority from repository plus provider-visible evidence.

A failed local readiness or status command is scoped evidence about that local path only. It never authorizes a temporary database, substitute service, different environment, or weaker verification path. When the target remains ambiguous, Codex stops before mutation or substitute creation and resolves the authority instead of improvising infrastructure. This guard is provider- and project-neutral and is enforced across the framework, global, and project instruction contracts.

## Fail-closed behavior by default

The framework treats implicit behavioral fallbacks as defects, not resilience. Placeholder, mock, sample, synthetic, fabricated, stale-cache, default-value, empty-success, substitute-service, provider/model downgrade, and swallowed-error paths may not turn a broken primary path into an apparently successful result. The responsible boundary must preserve the original cause and expose a typed or structured error with safe actionable diagnostics through the product interface and its observability path.

A genuine degraded mode is allowed only when the user or a project-specific contract explicitly requires it before implementation. The contract must define its trigger, semantics, provenance, user-visible degraded state, observability, recovery/removal condition, and tests for primary, degraded, and total-failure outcomes. In the absence of that evidence, Codex fails closed, removes an in-scope hidden fallback, and fixes the primary failure rather than masking it.

`setup.sh` installs the global working agreement at `~/.codex/AGENTS.md` when that path is absent or already framework-owned. An unmanaged file or symlink is preserved but setup fails before any writes: merge the agreement into the personal file or move it aside, then rerun setup. This fail-closed boundary prevents a successful-looking installation with no effective delivery policy. Agent profiles are managed regular TOML copies because native discovery does not reliably load symlinked profiles. Restart or start a new Codex task after installation.

## Native agent profiles

| Profile | Mode | Use |
|---|---|---|
| `explorer` | built in, read-only | evidence gathering and codebase mapping |
| `worker` | built in | narrow implementation ownership |
| `architect` | custom, high reasoning, read-only | shared contracts, migrations, and tradeoffs |
| `reviewer` | custom, high reasoning, read-only | correctness, security, and regression review |
| `tester` | custom, native model/effort selection | executable verification |

Keep parallel work read-heavy by default. Give each parallel writer a separate worktree and an explicit ownership boundary. The parent owns contracts and integration. Custom profiles inherit the current native model catalog, avoiding stale model pins after Codex releases. Only the judgment-heavy `architect` and `reviewer` profiles force high reasoning; the routine `tester` leaves both model and effort to native task-aware selection.

## Observable native workflow

For coupled behavior across files, a shared contract, or non-trivial risk, Codex must create a native plan before substantive tool work and keep it visible through short progress updates. Localized or mechanical work stays lightweight regardless of file count. Updates state the outcome, next steps, and which real sub-agents are active.

For deep audits, cross-system incidents, and independent read-heavy investigations, the parent delegates only separable work that improves the time to a sound decision. It announces an agent only after native delegation has actually started as `profile — model / effort — bounded responsibility`, and reports the result when it returns. It identifies a material skill as a skill, not as an agent: skills have no model. Profiles are native capabilities; the global challenge contract automatically selects bounded verification when substantive work starts. This restores accountability without reintroducing shell-created plans, fake status feeds, or lifecycle hooks.

High-risk changes get one native falsification-review pass after implementation and normal checks. The read-only `reviewer` is spawned with no inherited conversation turns or prior-agent history and receives only a neutral evidence bundle: the original request and acceptance criteria, actual diff, affected paths, applicable repository contracts, and executed checks with results. Implementer plans, reasoning, conclusions, memories, and earlier review commentary are deliberately excluded. If the active surface cannot prove the fresh-context boundary, the independent review remains unavailable rather than being represented by a context-inheriting substitute. The parent accepts only substantiated findings, makes any warranted revision, and reruns affected checks. Routine low-risk work skips the pass, and the contract forbids recursive debate loops, keeping the quality gain bounded in latency and token cost.

Model and effort routing remains native and user-owned. The framework's [paired evaluation protocol](docs/model-routing-evaluation.md) tests GPT-6 Luna, Sol and Astra with task-specific effort as bounded per-spawn candidates. The root and ordinary profiles stay unpinned; capability, quality, and complete-family usage must pass before candidate guidance is promoted. Exact commands and delivery claims require tool receipts and provider readback.

Material delivery is ordered: capability/auth preflight, plan challenge, implementation, real-runtime and visible in-app Browser debug where UI is runnable, result challenge, applicable independent review, then PR. A later green check cannot compensate for a skipped gate. CLI/IDE sessions cannot claim the desktop Browser gate; they stop before PR or hand acceptance to a desktop task. Reuse and simplicity are universal; security, performance, accessibility, observability and public-page SEO apply where the changed surface makes them relevant.

Use native `codex review` or the GitHub integration for routine pull-request review. The custom `reviewer` exists for the narrower high-risk falsification contract above, not as a replacement for native review surfaces.

Long-running goals advance through bounded execution epochs instead of one unbounded root turn. Each epoch owns one coherent batch, explicit checkpoint conditions, and at most one delivery lifecycle. External operations receive one status read and one bounded attached wait; continued requested monitoring moves to a native thread heartbeat, while unrequested waiting yields a checkpoint. Check evidence is reused while its source identity, command/configuration, environment, and provider inputs remain unchanged. See `docs/runtime-efficiency.md` for dependency-aware batching, execution lanes, reviewer identity, and rollout measures.

## Skills and integrations

Skills are a maintained local library, not a blanket prompt payload. `scripts/setup.sh` installs the curated universal core from `skills/core.txt`; `skills/packs/*.txt` provide explicit domain sets. Prefer native connectors or authenticated CLIs over wrappers for service/API operations; GitHub API work uses its connector or `gh`. Browser remains first-party for product UI acceptance and is used for service sites only for irreducibly visual/UI-only evidence after exact connector/CLI/API coverage is exhausted. Use DOM, console, and network before screenshots. Add MCP servers only for external context Codex does not already provide.

Service commands are evidence only after both transport and semantics are verified. An exit-zero empty result, a partial project list, mixed warning/data output, or an unsupported subcommand cannot prove that provider state is empty or unavailable. Target-dependent commands must reconcile explicit flags, environment, repository configuration, credentials/profile, and every local link/cache selector before use. Conflicts fail closed; after an incomplete CLI path, Codex uses the same-scope authenticated connector or direct API before considering a provider website, which remains UI-only evidence rather than a substitute data API.

Codex initially exposes only skill name, description, and path. That metadata catalog is bounded by the native context budget; the complete selected `SKILL.md` is loaded after selection, and routed references are read only when the skill requires them. Installing all 156 skills globally would reduce routing efficiency, so the default core remains one skill and domain packs stay project-scoped.

The corpus lifecycle, consolidation map, routing rules, and quality gates are documented in `docs/skills-governance.md`. Trusted community candidates are pinned to immutable upstream commits in `skills/community-pilot.tsv`; they remain opt-in until license, safety, routing, and representative-task evaluation pass. Use `bash scripts/community-skill-pilot.sh list` or read `docs/community-skills.md`.

## Capability discovery: local CLI before plugin gate

An uninstalled optional plugin is not evidence that a service is unavailable. Before requesting any plugin installation or connection, Codex inventories repository-native commands, PATH-available local CLIs, installed plugins/connectors, and native tools. It confirms a candidate CLI through `command -v`, version/help output, and a safe identity, authentication, or status check when the CLI supports one, then uses that CLI automatically when it provides the exact required operation.

Local CLIs and plugins remain complementary: selection depends on operation coverage, API parity, scripting/CI needs, authorization, and target environment. Plugin installation is requested only when the user explicitly named that plugin, existing callable tools and relevant CLIs cannot perform the operation, and the plugin contributes a unique required capability. Otherwise Codex continues with the existing CLI or reports the exact unsupported operation without inventing an installation gate.

## Native runtime features

Use Codex memories for optional cross-thread recall and native subagent workflows for current routing and lifecycle. Keep Auto-review as an explicit user-layer security choice; in the CLI, `--approve-for-me` enables it for an eligible run. Fast mode remains an explicit per-task choice because it trades additional credits for latency.

Codex owns task topology and coordination. A fork is the native history-backed branch for an explicitly requested alternative; a new task starts independent context, while a subagent remains inside the current request. Forks copy completed history, so an active unfinished turn is not a handoff boundary. Parallel writers use separate worktrees. Desktop task tools and CLI `codex agents`, `codex queue`, and `codex exec fork` own discovery, steering, and history branching; the framework adds no task registry, message queue, or fork wrapper. After resume or fork, consequential work waits for verification of the effective working directory and permission profile because an unavailable persisted profile can resolve to the current configured default.

Conversation export and shared snapshots are explicit disclosure actions, never automatic framework behavior. Review the exact transcript and audience before using native `/export` or share controls; native secret-pattern redaction does not establish that all sensitive content was removed.

Use native desktop or CLI import when the user explicitly chooses to bring supported setup and recent work from another agent. Imported history, memories, and opt-in Computer History can assist recall, but never replace repository instructions or fresh environment/provider evidence. Computer History remains availability- and permission-gated; the framework does not enable it or recreate it.

For UI diagnosis in the desktop app, prefer Browser Developer mode when DOM, console, network, runtime-error, or profiling evidence is needed. Full CDP access remains an explicit setting and per-site approval, never a framework bypass.

Dynamic workflows remain native compositions: goal and plan for state, skills for repeatable method, subagents for bounded parallel work, native rules for permission decisions, plugins/MCP for authorized data and actions, and Scheduled tasks for stable recurring execution. The framework does not add a workflow engine or prompt router.

Framework maintenance has a mandatory native-capability currency gate. Every audit, improvement, consolidation, or release reads the current official Codex manual, changelog delta, and latest stable release notes; maps each relevant delta to `adopted`, `replaced`, `removed`, `retained`, or `permission-gated`; searches for overlapping local implementations; and applies justified cleanup. `docs/native-capability-ledger.json` is machine-checked against the active CLI, a seven-day review window, official source coverage and SHA-256 content fingerprints, repository evidence, a year-agnostic live changelog boundary, and the latest stable GitHub release. Static health and live release gates fail closed when that evidence is stale or any official source changes without review. See `docs/native-capability-review.md`.

## Interactive web and mobile development

Runnable web implementation and diagnosis lock to an early repository-native dev server plus the visible in-app Browser. Codex reuses that binding, recovers a lost tab inside it, opens the affected localhost route, and iterates with DOM, console, network, runtime, interaction, responsive, and fresh-load evidence. Chrome or Edge is used only when the user explicitly names it for the current task and never substitutes for required in-app acceptance. Invisible/headless E2E remains supplementary regression coverage.

Runnable native-mobile work similarly boots or attaches to a repository-configured visible simulator, emulator, or device and launches the app early. Repository/platform tooling owns target selection; the framework does not hardcode a device or implement an emulator manager. Parallel UI writers require separate worktrees, ports, servers, and task-owned tabs/targets. Normal closeout stops only exact task-owned resources. See `docs/interactive-development.md`.

Browser availability, localhost/site access, full CDP, Record & Replay, device SDKs, and consequential permissions remain native user/workspace gates. The framework automatically selects and uses an available approved capability, but never bypasses its one-time setting or approval and never claims interactive verification when the gate blocked it.

Project safety uses native `.codex/rules/` and approvals. The former shell parser and hook installer have been removed: they could reject harmless text, miss equivalent commands and override valid user branch instructions. Native `codex/` is the default unless the user or project specifies another convention. No safety policy is advertised as a complete shell interpreter.

The tracked project config contains only measured tool-output preference and native concurrency. No lifecycle hooks, task state machine or prompt routing wrapper is installed.

Desktop and CLI consume the same supported project instructions, config, profiles and skills. This is configuration parity, not capability identity: Browser is desktop-only, plugin availability varies by surface, and Linux desktop preview may omit capabilities available elsewhere. Unsupported capabilities remain explicit native boundaries rather than framework fallbacks. The framework contains no surface-specific runtime branch and injects no SessionStart context, which keeps startup tokens stable. Run `bash scripts/surface-parity-check.sh` after changing the runtime surface.

Generic behavior is defined once in the global working agreement. Repository and generated project instructions contain only closer facts and overrides; deterministic byte budgets reject renewed policy duplication. Native prompt metadata exposes the single core framework skill without injecting full `SKILL.md` bodies or generated briefs. Prompt caching and persisted reasoning remain native model/runtime capabilities rather than framework cache wrappers; measure their usage at the provider surface instead of inferring savings from local files.


## Automatic challenge and worktree isolation

Every native task receives a bounded evidence debate per decision or delivery batch, never recursively per command or leaf step. Trivial/read-only work gets one exchange; material work gets pre-mutation and post-implementation exchanges. Every finding must preserve challenge → developer response with a typed evidence pointer → verification → same-challenger disposition → parent adjudication. Versioned receipts classify each finding as `compliant`, `violation`, or `unverifiable`; missing native family events never become success. Only applicable high-risk work adds one fresh read-only falsification pass. Agent agreement is not proof, and debate is not an unbounded voting loop.

Every Git-project mutation uses a task-owned native worktree, including single-agent work. Tracked config travels with Git; only identified required ignored config is copied with permissions preserved and environment identity checked. Other models' dirty files, caches, credentials and worktrees are not shared or swept up. After verified merge and clean named-base synchronization, remove only clean owned worktrees and merged branches. Installed releases are durable and outside temporary task cleanup. See `docs/runtime-efficiency.md` for the complete evidence contract.

For broad goals, the parent operates as lead while native workers own independent substantive lanes in separate worktrees. Blockers are lane-scoped; the whole goal blocks only when no ready lane remains. Latest user steering overrides stale goal or compacted context. Safe continuity records credential locations and identity metadata, never secret values. Consequential confirmations are current-turn, single-use and target-specific; external state changes use read/compare/preview/mutate/read-back. Scope discovered during work is classified before it can expand the request.

## Token efficiency

This repository leaves stable request compression, remote compaction, skill search, cached web search, model choice, effort, and auto-compaction thresholds at their native defaults. It retains one evidence-backed local preference: tool results retained in context are capped at 4,000 tokens. Existing user-owned config is preserved. The global agreement requires targeted reads and forbids model/effort downgrades solely for token savings.

`scripts/framework-token-budget-check.py` fails on oversized always-on instructions, prompt/compaction overrides, explicit disabling of stable optimizations, model/effort pins, a larger tool-output retention limit, or deterministic busy-polling evidence in `--rollout PATH`. The rollout diagnostic uses thread-owned counters, detects event-counter resets, and separates response/turn/thread usage plus custom/function text and image output without claiming that raw JSONL bytes were retained in later context. Baseline evidence and interpretation boundaries are in `docs/token-efficiency.md`.

## Framework checks

```bash
bash scripts/framework-eval.sh
python3 scripts/framework-token-budget-check.py --live
bash scripts/framework-drift-check.sh
bash scripts/surface-parity-check.sh
bash scripts/framework-skill-governance.sh
bash scripts/framework-version-drift-check.sh
bash scripts/framework-version-drift-check.sh --self-test
# Network-backed resolution from current distribution channels:
bash scripts/framework-version-drift-check.sh --live
bash scripts/framework-skill-sync.sh --check .
bash scripts/framework-doctor.sh
bash scripts/framework-skill-loader-live-eval.sh
bash scripts/framework-release.sh
${CODEX_HOME:-$HOME/.codex}/bin/codex-framework-stack-context project /path/to/project --format markdown
${CODEX_HOME:-$HOME/.codex}/bin/codex-framework-stack-context latest nextjs react nodejs --format markdown
SKILL_QUALITY_ARTIFACT_DIR=/tmp/skill-quality bash scripts/framework-skill-routing-live-eval.sh --skill nextjs-development
# Strict per-skill semantic evaluation (after a routing artifact exists):
python3 scripts/framework-skill-quality.py semantic-live --skill nextjs-development --artifact-dir /tmp/skill-quality --routing-artifact /tmp/skill-quality/routing-nextjs-development.json
python3 scripts/framework-skill-quality.py certify --skill nextjs-development --artifact-dir /tmp/skill-quality
bash scripts/framework-health.sh
# Optional model-backed delegation and service-operation regression checks:
bash scripts/framework-live-eval.sh
```

For a fresh corpus-wide run, create an empty artifact directory, run `routing-live --jobs 8` without `--skill`, then run `full-live --jobs 8` against `routing-all.json`. Routing batches at most 32 cases sharing one exact catalog/topology while retaining three independent majority trials; the full routing corpus is capped at 150 model calls. `full-live` freezes model, effort, CLI, routing-artifact hash, and all semantic source/evaluator digests in an immutable run manifest; children and parent abort on mid-run source drift. `full-live --resume` requires that same manifest and accepts only already-passing artifacts whose evaluator, model, effort, skill, contract, routing, and raw-evidence digests still validate; it never retries a failed case to green. After an intentional semantic source or evaluator change, `full-live --refresh` rebuilds every current artifact under a new immutable manifest while reusing only raw calls whose receipts still exactly match output, prompt, schema, model, effort, CLI and canonical per-skill artifact path. Drifted or corrupt calls refresh individually; symlinked or cross-skill evidence fails closed.

The release gate is incremental by default. It recomputes every skill, contract, routing, semantic, evaluator, runtime, and case-count identity before deciding what is stale; only stale skills receive new routing and semantic model calls. Unchanged rows must match the previous committed release evidence byte-for-byte. The new receipt records the baseline evidence commit and digest plus the exact fresh/reused partition, and validation reconstructs that lineage from Git. This is evidence reuse, not an unbound cache: missing, edited, non-ancestor, stale, or malformed baseline evidence fails closed.

`framework-health.sh` validates source and is safe for CI. `framework-doctor.sh` reports the actual installed source, canonical skills, ownership state, profiles, rules, prompt metadata and native diagnostics. Release certification is a separate explicit `--evidence` check; project validation belongs to source health. A dirty development source can be active without being a certified release. `framework-skill-loader-live-eval.sh` uses an ephemeral native `codex exec` to prove initial-turn discovery, end-of-file visibility, required-reference loading, and an observable tool trace without the forbidden reference. It does not claim to force native auto-compaction: that boundary has no stable non-interactive trigger in the pinned CLI and must not be represented by a simulated local workflow. `framework-release.sh` validates schema-checked, prompt/output-digest-bound raw model evidence, then writes a retained compact per-skill attestation plus exact gate commands, outputs, and hashes to `docs/framework-release-evidence.json`. Unchanged per-skill attestations may be reused across a stable CLI patch update within the same major/minor line; the release still reruns current-CLI skill-loader, native-capability, and provider-routing canaries. A major/minor CLI change, evaluator/model/effort change, or skill/contract/digest change invalidates the affected attestations. This keeps runtime compatibility fail-closed without turning every patch-level picker or provider fix into 156 duplicate semantic runs. Reused provenance is anchored to the exact committed baseline-evidence bytes. When a pre-squash source object is available its tree digest is recomputed; a clean post-squash clone may validate the committed evidence anchor without requiring the discarded branch object. The minimum raw traces for the disposable synthetic delivery fixtures are retained at `docs/framework-release-delivery-evidence/`, excluded from the source digest to avoid a cycle, and bound by per-file receipt digests so a fresh CI checkout can revalidate them; other raw model transcripts remain task-owned ephemeral data. The manifest is bound to a real committed source tree. Release evidence still expires after seven days and whenever its source digest changes.

The deterministic checks validate native configuration, profile boundaries, plugin packaging, surface parity, wrapper removal, native safety policy, skill ownership/review metadata, exact core/pack coverage, reachable references, unsafe cleanup recipes, dynamic release resolvers, numeric bootstrap pins, and a digest-bound contract for every skill. Quality is conjunctive across every assertion, case, and all ten dimensions; both major and critical failures block. The 542 fixture-backed scenarios include semantic GitHub/Browser routing and public-surface authority counterexamples and are distributed across ten bounded domain profiles rather than one universal repository fiction. Model-backed evaluators run from neutral home/working directories with repository and user instructions ignored. Routing uses three fresh trials and recomputes artifact majorities during consumption; semantic certification produces a draft, performs exactly one assertion-blind self-falsification/revision against the supplied skill and fixture, then sends only the revised answer to an independent hidden-criteria judge. See `docs/version-currency.md` and `docs/skill-quality-standard.md`.

## Behavioral acceptance

`bash scripts/framework-live-eval.sh` is policy classification only. `bash scripts/framework-live-eval.sh --runtime-policy` batches all runtime cases into three fresh trials, requires a per-case two-of-three majority, and reports exact provider input/cache/output/reasoning usage instead of paying one full-context invocation per case. Run `bash scripts/framework-live-eval.sh --behavior --artifact-dir /absolute/fresh/path` for tool-enabled native Codex tasks in disposable Python and Node projects, including an actual authenticated-fixture CLI route for provider data. No model/effort override is supplied. Independent graders check results and successful command events; self-ratings are ignored. Use `python3 scripts/framework-project-behavior-eval.py --self-test` for grader counterexamples. Fixture success does not certify long-running Goal suspension, hosted-project acceptance, or visible desktop Browser acceptance. Cross-session continuity, native wait/heartbeat behavior and long-running compaction still require live-project evidence.

## Supported installations

`python3 scripts/framework-delivery-behavior-eval.py --live --artifact-dir /absolute/fresh/path` exercises automatic tester challenge, pending-evidence refusal, false-positive rebuttal, authorized CI repair, configuration transfer, and merge cleanup. It records native commands and independent final-state measurements. Verification commands in these fixtures run separately so each has its own exit status. Release validation consumes the raw artifacts before producing a compact receipt with source/runtime identity and content hashes. These hashes establish integrity relative to the trusted local collector; they are not signatures against an administrator forging the entire artifact store. Use `bash scripts/framework-release.sh --quality-dir /absolute/validated/corpus --delivery-artifact-dir /absolute/validated/delivery` to reuse unchanged evidence instead of repeating model calls. Missing, stale or invalid evidence fails validation.

The installation contract requires Git, Bash and Python 3.11+ as python3. CI covers Linux and macOS; Windows uses WSL with the same Linux installation contract. Native Windows without Bash is not certified. Local source paths are resolved on each machine rather than copying another machine's installation state. Default doctor reports installation/source and native runtime; use `--evidence` to request release certification. A broken legacy link is repaired by running setup from a clean detached reviewed checkout. User-owned collisions remain explicit and unchanged.
