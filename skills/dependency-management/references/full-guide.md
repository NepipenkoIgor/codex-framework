# Dependency automation and package-manager notes

Load this reference only when exact configuration is required. The repository's package manager, updater, registry, CI policy and installed configuration schema remain authoritative.

## Package-manager boundary

- Detect the authoritative manifests, workspace graph, lockfile format, runtime/version-manager files, registry config and frozen/locked install command. Do not switch managers or hand-edit a generated lockfile.
- Resolve the requested target from the official registry/advisory channel at execution time. Review engine, peer, native ABI/platform, compiler/framework, test-runner and deployment compatibility as one graph.
- Keep application pins, library ranges, peer ranges, workspace protocols and generated artifacts consistent with repository policy; no single pinning rule fits every artifact.
- Inspect lifecycle scripts, provenance/integrity, package contents and transitive changes when the trust or blast radius warrants it.

## Updater boundary

- Validate Renovate, Dependabot or another updater configuration against the installed/provider schema. Do not copy remembered keys, schedules, action majors or presets.
- Group only dependencies that must move together or have proven coupled verification. Keep majors, runtimes, native packages, security migrations and generated-schema changes separately reviewable unless evidence supports a coordinated set.
- Choose schedule, cooldown, concurrency and abandonment from team review capacity, release cadence and CI throughput. Avoid universal PR counts or freshness thresholds.
- Automerge is an explicit allowlist: low-risk class, reproducible lock update, required CI and provenance, protected branch policy, observation window where needed, and tested rollback. Never blanket-automerge because a version is patch-level or security-labelled.
- Third-party CI actions follow repository supply-chain policy, including immutable revisions when required. Fork/untrusted workflows must not receive write tokens, release credentials or cache authority.

## Verification and evidence

Run the authoritative locked install/restore, inspect manifest and lock diff, and execute focused API tests plus affected type/lint/build/test, native/platform, generated-artifact and deployment checks. When a migration has a supported mixed-version window, verify the applicable old/new combinations; otherwise prove the documented coordinated cutover and recovery path. Record official release/advisory evidence and distinguish a green updater PR from caller-visible production compatibility.
