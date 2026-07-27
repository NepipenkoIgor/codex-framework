# Package versioning and release notes

Use the repository's installed release tool and configuration schema. Verify command and action syntax from local help/types and current official documentation; do not copy remembered action majors, runtime versions or runner labels.

## Version model

- Choose independent, fixed/locked-step or grouped versioning from consumer compatibility and release ownership. Coupled packages need an explicit compatibility rule; unrelated packages should not churn solely for visual consistency.
- Require a reviewable change record for public behavior, with package scope, change class, consumer impact and migration notes. Generated changelog text is an artifact to review, not authority.
- Pre-release channels need a defined audience, tag/channel, dependency-range behavior, promotion path and cleanup. Do not let a pre-release accidentally satisfy stable consumers.

## Release workflow

1. Validate package graph, changed package set, public API/schema diff, generated artifacts and version policy.
2. Produce the version/manifest/lock/changelog change with the installed tool in a reviewable branch or pull request.
3. Run required package and consumer checks, build reproducible artifacts once, and bind provenance/signing/attestation as policy requires.
4. Publish under least-privilege environment approval, then verify registry metadata, tags/channels, package contents and a clean consumer install.
5. Define recovery before release: deprecate/yank where supported, publish a compatibility fix, move a mutable channel only with care, and communicate irreversible consumption.

Verify no-change, one-package and coupled-package cases, prerelease promotion, failed partial publish, duplicate rerun, registry ambiguity, generated-file drift, old/new consumer compatibility and rollback/recovery.
