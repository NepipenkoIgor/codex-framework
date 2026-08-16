---
name: seo-audit
description: Audit crawlability, indexation signals, canonicalization, links, metadata, structured data, internationalization, rendered content, and search performance. Use for an evidence-based read-only SEO assessment; do not use when implementation is requested or when production/search evidence is unavailable but certainty is expected.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.1
  argument-hint: "site/environment, representative templates, search markets, analytics/search-console access, scope"
---

# SEO Audit

Read [the full framework and category checklist](references/full-guide.md) only for the affected templates and platform.

## Evidence

Read repository instructions, manifests/lockfiles, framework/SEO configuration, target templates/implementation, adjacent tests and recent failure evidence. Report supplied/observed repository inspection separately from commands or browser/search checks executed during the audit; “no command ran” must not erase already supplied evidence. Start with authoritative robots/sitemap/canonical/hreflang/structured-data output, representative rendered pages, response headers/statuses, internal link graph, performance field data, and available search-console/analytics evidence. Do not infer production indexation solely from source code or a local crawl.

Revalidate volatile search behavior at execution time against current engine-owned official guidance for JavaScript rendering, sitemaps, snippets, localization/hreflang and structured data. Analyze JavaScript rendering as three separate evidence boundaries: whether URLs/content are discovered, whether required resources are crawlable and available, and whether content appears within the engine's rendering/indexing timing. Preserve documented limits only with current provenance and never invent that tool use is prohibited; when live guidance cannot be checked, mark the claim unresolved.

## Audit

1. Segment pages by template, intent, locale, indexability, and traffic/value.
2. Check crawl paths, directives, status chains, duplicates, canonicals, pagination, and orphan pages.
3. Inspect rendered titles, descriptions, headings, content, links, media alternatives, and structured data.
4. Evaluate locale/hreflang consistency and mobile/rendering behavior.
5. Correlate technical findings with field performance and search evidence where available.
6. Rank only reproducible findings by severity, affected population, confidence, and remediation dependency.

## Output Contract

- Scope, environments, templates, and evidence sources
- Findings with severity, confidence, affected URLs/templates, and reproduction
- Prioritized remediation plan separated from implementation
- Missing production/search evidence and residual uncertainty

## Verification Boundary

Reproduce each finding against representative URLs and the relevant raw response, rendered page, headers, sitemap/robots output, crawl graph, or available search-console evidence. A source-only hypothesis remains explicitly unverified. Do not mutate the site during an audit, promise ranking/indexation outcomes, or turn remediation suggestions into unrequested implementation.

Completion depends on the manifest-defined focused test, affected test, type-check and build categories plus applicable crawl/render/schema checks; exact commands come from the repository and unavailable execution remains `Not available`, not optional. Use a task-owned browser/crawl session and close or clean only the session and artifacts started by this audit.

## Done Criteria

- Every finding includes affected scope, reproduction, evidence, confidence, and remediation dependency.
- Production/search evidence gaps are visible and constrain conclusions.
- Audit and implementation remain separate routing and authorization boundaries.
