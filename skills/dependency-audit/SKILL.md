---
name: dependency-audit
description: Audit project dependencies for CVEs, outdated packages, unused dependencies, license compliance, duplicates, and lockfile integrity across npm, NuGet, pip, Cargo, and Go modules
metadata:
  version: 1.3
  argument-hint: "package manager (npm/npm/NuGet/pip), audit focus (CVEs/outdated/unused/licenses), minimum severity level, compliance framework (if any)"
---

Audit $ARGUMENTS. READ-ONLY analysis — never modify manifest files, lockfiles, or install packages.


## Example

Auditing an npm project with a typical Next.js stack:

```
Dependency Audit Report
========================
Project: acme-dashboard
Ecosystem: npm
Manifest: package.json
Lockfile: package-lock.json (present, synced)
Total dependencies: 42 direct, 387 transitive

--- Vulnerabilities (2 findings) ---

[CRITICAL] CVE-2025-29927 — next@14.1.0
  Description: Authorization bypass in Next.js middleware (CVSS 9.1)
  Fixed in: 14.1.4
  Type: direct
  Upgrade: npm install next@14.1.4

[HIGH] CVE-2024-55565 — tar@6.1.11
  Description: Path traversal via crafted tar entries (CVSS 7.5)
  Fixed in: 6.2.1
  Type: transitive (via npm-packlist -> node-tar)
  Upgrade: npm audit fix --force (or override in package.json)

--- Outdated Packages (1 finding) ---

[HIGH] react: 18.2.0 -> 19.1.0 (major)
  Changelog: new compiler, Server Components stable, ref as prop
  Upgrade: npm install react@19 react-dom@19 (review breaking changes first)

--- Unused Dependencies (1 finding) ---

[LOW/NEEDS REVIEW] classnames
  Evidence: no imports found — project uses clsx instead
  Action: npm uninstall classnames

--- License Issues (1 finding) ---

[MEDIUM] pdf-lib@1.17.1 — Custom (SEE LICENSE IN ...)
  Conflict: project is MIT, dependency has a custom non-standard license
  Action: review license text manually, verify compatibility
```

Output format:

```
Dependency Audit Report
========================
Project: [name]
Ecosystem: [npm/NuGet/pip/cargo/go]
Manifest: [file path]
Lockfile: [present/missing/outdated]
Total dependencies: N direct, N transitive

--- Vulnerabilities (N findings) ---

[SEVERITY] CVE-YYYY-NNNNN — package@version
  Description: ...
  Fixed in: version
  Type: direct / transitive
  Upgrade: [specific command]

--- Outdated Packages (N findings) ---

[SEVERITY] package: current -> latest (major/minor/patch)
  Changelog: [key breaking changes for major updates]
  Upgrade: [specific command]

--- Unused Dependencies (N findings) ---

[LOW/NEEDS REVIEW] package
  Evidence: no imports found matching this package
  Note: [if potentially implicit usage]
  Action: remove from [manifest file] or verify usage

--- License Issues (N findings) ---

[SEVERITY] package@version — LICENSE_TYPE
  Conflict: [project license] is incompatible with [dependency license]
  Action: [replace, request exception, or verify compliance]

--- Duplicates (N findings) ---

[LOW/MEDIUM] package: versions [1.x, 2.x, 3.x]
  Size impact: ~NKB duplicated
  Fix: [specific dedupe or upgrade command]

--- Heavy Dependencies (N findings) ---

[LOW] package — NKB unpacked
  Alternative: [lighter package] — NKB
  Migration: [brief migration note]

--- Lockfile Status ---

[STATUS] [details]

========================
Audit Summary
========================
Critical: N
High:     N
Medium:   N
Low:      N

Top priorities:
1. ...
2. ...
3. ...

Recommended actions:
- [specific commands to run]
- [packages to replace]
- [manual reviews needed]
```

