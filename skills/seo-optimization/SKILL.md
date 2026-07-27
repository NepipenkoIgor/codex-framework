---
name: seo-optimization
description: Implement evidence-backed technical SEO changes to crawling, indexing signals, canonicalization, metadata, structured data, internationalization, rendering, and performance. Use when changing the site to address verified SEO findings; do not use for a read-only audit, content strategy, or access control.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 2.0
  argument-hint: "verified finding, affected URL templates, framework, target search engines, deployment evidence"
---

# SEO Optimization

## Repository and Evidence Discovery

Start from reproducible findings with affected URLs/templates and desired search behavior. Inspect route generation, rendering output, metadata/canonical/hreflang utilities, redirects, robots/meta/X-Robots rules, sitemap generation, structured data, pagination/facets, status codes, internal links, deployment/CDN behavior, analytics, and any available search-console or URL-inspection evidence. Preserve working abstractions and implement at the shared template boundary rather than patching individual pages.

Do not infer an indexing defect from local source alone. Search engines can render JavaScript, but rendering cost, timing, blocked resources, errors, and delayed content still matter. Validate the delivered HTML/rendered page and search-engine evidence.

## Workflow

1. Reproduce and classify the finding: crawl discovery, response/status, render, indexability, canonical cluster, duplication, international targeting, structured data, internal linking, or performance.
2. Define the intended URL state and competing signals across HTML, headers, sitemap, redirects, links, and robots controls.
3. Implement the smallest shared change compatible with the installed framework and hosting layer.
4. Test representative, edge, locale, parameterized, paginated, error, redirected, authenticated, and noindex URLs.
5. Deploy, inspect actual responses/rendered output, and monitor crawl/index/search evidence without promising ranking outcomes.

## URL, Crawl, and Indexing Signals

- Return truthful status codes. Use permanent/temporary redirects deliberately and avoid chains/loops.
- Canonical points to the preferred indexable URL and agrees with redirects, internal links, hreflang, and sitemap membership. A canonical is a signal, not access control or a guaranteed directive.
- `robots.txt` controls crawling, not confidentiality or reliable deindexing. Protect private routes with authentication/authorization; use supported noindex mechanisms where indexing must be discouraged.
- Keep sitemaps limited to preferred indexable URLs, with accurate locations and modification data when trustworthy.
- Define policy for facets, search, tracking parameters, pagination, print/alternate formats, and duplicate route aliases instead of blanket blocking.

## Metadata and Social Surfaces

- Generate unique, truthful title/description/canonical metadata at the route-template boundary with deterministic fallbacks.
- Validate Open Graph/social metadata only for surfaces the product supports.
- Do not enforce universal character counts as correctness rules; detect truncation risk, duplication, missing intent, and misleading content.
- Avoid using client-only state for metadata required in the initial response unless the target crawler/render path is verified.

## Structured Data

- Add only schema types that accurately represent visible page content and comply with the target search engine's current eligibility rules.
- Multiple relevant entities/types may coexist; connect them consistently rather than enforcing “one primary schema”.
- Validate syntax and required/recommended properties, then verify rendered output. Structured data never guarantees a rich result.
- Do not promise FAQ rich results for ordinary SaaS pages; current Google eligibility is limited. Re-check official guidance before implementation.

## International and Alternate URLs

- Use valid language or language-region tags appropriate to the content; language-only tags such as `de` or `en` are valid.
- Hreflang sets are reciprocal, canonical-compatible, and complete for intended alternates; add `x-default` only when a genuine default/selector exists.
- Do not redirect users or crawlers solely from guessed language/region without an accessible override and product decision.

## Rendering and Framework Capability

Inspect the installed framework, types, generated route behavior, and deployment adapter before applying a recipe. SSR, static generation, streaming, ISR/cache controls, and client rendering are implementation choices whose SEO effect must be measured on delivered output. Do not copy versioned Next/Nuxt/Angular/Vue/Svelte recipes from memory; resolve current capabilities and preserve existing pins unless migration is explicit.

## Performance Boundary

Use real-user and controlled lab evidence to address discoverability/rendering or user-experience bottlenecks. Optimize the measured LCP/INP/CLS contributors without claiming that one score or framework switch guarantees rankings. Coordinate image/font/script/cache changes with accessibility and product behavior.

## Verification

- Crawl representative URLs and assert status, redirect, canonical, robots/meta, sitemap, hreflang, internal-link, and structured-data consistency.
- Inspect raw response and rendered DOM with scripts enabled/disabled as relevant; capture console/network/render failures.
- Verify authenticated/private routes cannot be accessed without authorization; robots rules are not treated as security.
- Test locale, pagination, facet, parameter, duplicate, error, and redirect edge cases.
- After deployment, use available URL-inspection/search-console/log evidence and record uncertainty where production evidence is unavailable.

## Output Contract

Report the verified findings addressed, affected templates/URLs, intended signal matrix, files and shared abstractions changed, framework capability evidence, executed crawl/render/schema/performance checks, deployment observations, unresolved indexing uncertainty, and monitoring/rollback plan. Never guarantee rank, traffic, crawl timing, or rich-result eligibility.

## Official Provenance

- Google JavaScript SEO: `https://developers.google.com/search/docs/crawling-indexing/javascript/javascript-seo-basics`
- Google localized versions/hreflang: `https://developers.google.com/search/docs/specialty/international/localized-versions`
- Google structured-data policies: `https://developers.google.com/search/docs/appearance/structured-data/sd-policies`
- Google FAQ eligibility change: `https://developers.google.com/search/blog/2023/08/howto-faq-changes`

Re-check official target-engine and framework documentation for volatile behavior.

## Done Criteria

- Findings are reproducible and changes occur at the correct shared boundary.
- Crawl/index/canonical/hreflang/sitemap/redirect signals agree for representative and edge URLs.
- Structured data matches visible content and current eligibility guidance without promises.
- Private content relies on authorization, not robots controls.
- Delivered and rendered production behavior is verified or explicitly marked unverified.
