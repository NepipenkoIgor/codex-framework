---
name: google-search-console
description: Audit, configure, and debug Google Search Console properties, search performance, sitemaps, and indexed URL status. Use when work explicitly involves Google Search Console or its API; route site-only SEO assessment and implementation without GSC evidence to the dedicated SEO skills.
metadata:
  owner: codex-framework
  reviewed: "2026-08-22"
  version: 1.0
  argument-hint: "site/repository, environment, GSC property, date range, read-only or mutation scope"
---

# Google Search Console

Operate across repositories without embedding a project, domain, Google account, property, credential, or secret in the skill.

## Establish Authority

Derive the canonical public site and environment from current repository and deployment evidence. Before opening or changing Search Console, resolve the exact Google account, property (`sc-domain:` or URL-prefix), verified ownership/access level, deployment target, and any separate DNS authority. A signed-in Browser session proves only the visible account and access it actually shows.

Inventory repository-native commands, installed connectors or CLIs, an existing signed-in in-app Browser session, and official API credentials before declaring a capability missing. Prefer Browser for property selection, ownership flows, reports, manual actions, security issues, and other UI-only evidence. Prefer the official Search Console API for repeatable Search Analytics, property, sitemap, and indexed-version URL Inspection work. Use read-only access by default and request write capability only for an authorized property or sitemap mutation.

## Diagnose

Correlate three evidence boundaries instead of substituting one for another:

1. Repository and deployed output: status/redirects, `robots.txt`, sitemap generation and reachability, canonical and robots directives, internal links, structured data, rendered content, and representative mobile behavior.
2. Search Console: property identity, performance dimensions and date range, page/indexing signals, submitted sitemap status/errors/warnings, inspected indexed URL status, and relevant UI reports.
3. Google-owned current documentation for volatile API/report semantics and limitations.

Treat Search Analytics rows as scoped report data, not a complete URL/query inventory. URL Inspection API describes the version in Google's index; it is not a live URL test and does not request indexing. Do not misuse the Indexing API for ordinary pages. Sitemap submission confirms the request, not successful crawling or indexing, and sitemap `isSitemapsIndex`/contents indexed counts must not be treated as current authoritative success evidence where Google marks them deprecated.

Rank findings by impact, affected scope, confidence, and dependency. Separate a repository defect, deployment defect, Search Console configuration issue, Google processing delay, and missing evidence.

## Configure and Fix

Read-only audits do not authorize mutations. When the user requests configuration or repair, change only the resolved in-scope property and repository/deployment target. Prefer fixing shared generators or templates over patching individual URLs. Property creation/verification, DNS changes, sitemap submit/delete, deployment, and production edits retain their own authority and verification boundaries; stop when the required account, ownership, or environment cannot be proven.

After code changes, run repository-owned focused checks and inspect the deployed result in the visible Browser. After Search Console changes, re-read the property/report or API response. Record Google processing as pending when it has not completed; never promise ranking, crawling, or indexing and never fabricate immediate acceptance.

## Current Official Sources

Before relying on version-sensitive behavior, verify the relevant Google-owned documentation:

- Search Console API surface: `https://developers.google.com/webmaster-tools/v1/api_reference_index`
- URL Inspection semantics: `https://developers.google.com/webmaster-tools/v1/urlInspection.index/inspect`
- Sitemaps resource and deprecated fields: `https://developers.google.com/webmaster-tools/v1/sitemaps`

## Output Contract

- Resolved site/environment, Google account visibility, property, access level, scope, and evidence sources
- Findings with affected URLs or report dimensions, reproduction, confidence, and responsible boundary
- Changes actually made, exact verification, and separate pending Google processing
- Missing access/evidence, residual risk, and the next observable check
