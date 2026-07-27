---
name: dependency-audit
description: Perform a read-only dependency audit using current manifests, resolved lockfiles, advisories, licenses, provenance, usage, and runtime reachability. Use for findings and risk assessment; use dependency-management for update automation or remediation.
metadata:
  owner: codex-framework
  reviewed: "2026-07-27"
  version: 2.0
  argument-hint: "repositories/workspaces, package managers, deployed artifacts, severity/license policy, current advisory access"
---

Audit $ARGUMENTS without modifying manifests, lockfiles, caches, installations or registry state.

## Establish resolved inventory

Read instructions, all workspace manifests and lockfiles, runtime/engine files, package-manager configuration, build/deployment manifests, generated SBOMs if authoritative, and license/security policy. Identify production, development, build, optional, peer, bundled, container and transitive dependencies as resolved for each shipped artifact. Lockfiles and actual deployed artifacts outrank remembered examples.

Use installed package-manager commands only in read-only modes. Never run `npm audit fix`, `--force`, update/install, lockfile regeneration or scripts during an audit. Version-specific command syntax must come from installed CLI help or matching official docs.

## Evidence

- CVEs/advisories: query current authoritative advisory/vendor sources, record advisory ID, affected/fixed ranges, publication/update time, ecosystem/package identity and exact resolved version. Confirm vulnerable code or configuration reachability and compensating controls before assigning application severity.
- Licenses: use package metadata and repository license text for the resolved artifact; evaluate direct/transitive use, distribution/linking context and project policy. “Unknown” is not automatically forbidden, and package names are not license proof.
- Integrity/provenance: verify lockfile integrity fields, registry/source URL, commit/digest/signature/attestation where available, lifecycle scripts, substitutions, vendoring and manifest-lock mismatch. Preserve uncertainty rather than inventing trust.
- Outdated/duplicate: resolve current stable/support data dynamically from official distribution channels, but distinguish “newer exists” from security, support or compatibility risk. Multiple versions may be intentional; measure size/runtime/patch divergence.
- Unused: combine imports, dynamic loading, scripts, build config, plugins, reflection/codegen and deployment entry points. Static non-reference alone is insufficient proof.

Do not cite stale package examples or remembered “latest” versions. Timestamp external evidence and state when current registry/advisory access was unavailable.

## Output

Report inventory scope and provenance, then findings ordered by evidence-based risk. Each includes exact package/artifact/version/path, direct/transitive and environment, advisory/license/source evidence, reachability, impact, confidence, supported remediation range, compatibility/rollback notes and verification needed. Separate vulnerable, stale, unused, duplicate, license and integrity findings. Do not change dependencies or claim safety from a zero-exit scanner alone.
