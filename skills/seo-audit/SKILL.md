---
name: seo-audit
description: Audit sites for SEO issues — crawlability, indexation, broken links, duplicate content, canonical chains, Core Web Vitals, structured data, and keyword cannibalization
metadata:
  version: 1.5
  argument-hint: "site URL, page count, target keywords, framework (framework detection), CMS if applicable"
---

Audit $ARGUMENTS for SEO issues.

## Tool Integration

- **browser automation**: Use browser navigation and snapshot tools for runtime crawlability checks, JS-rendered content verification, and Core Web Vitals assessment.
- docs lookup tools: Fetch current SEO library docs (e.g., next-seo, react-helmet) on demand.

## Audit Scope

### Crawlability and Indexation

Robots.txt analysis:
- Verify robots.txt exists and is accessible at `/robots.txt`
- Check for overly broad `Disallow` rules blocking important content
- Verify CSS/JS is not blocked (required for rendering)
- Confirm `Sitemap:` directive points to a valid sitemap URL
- Check for conflicting rules between user-agent sections
- Flag `Disallow: /` on production sites (blocks all crawling)

Sitemap validation:
- Parse sitemap.xml and sitemap index files
- Verify all listed URLs return 200 status
- Check for URLs in sitemap that are noindex, redirected, or 404
- Verify `lastmod` dates are present and accurate (not all set to the same date)
- Check file size (max 50MB) and URL count (max 50,000 per sitemap)
- Verify sitemap is referenced in robots.txt
- Check for URLs missing from sitemap that should be included

Noindex leaks:
- Scan for pages with `<meta name="robots" content="noindex">` that should be indexed
- Check HTTP response headers for `X-Robots-Tag: noindex`
- Verify staging/dev environments are not accidentally indexed
- Check for noindex on paginated pages that should be indexable

Orphaned pages:
- Identify pages with no internal links pointing to them
- Cross-reference sitemap URLs against internal link graph
- Flag content pages reachable only via sitemap (no navigation path)

Thin content:
- Flag pages with fewer than 300 words of meaningful content
- Identify pages with high boilerplate-to-content ratio
- Check for near-duplicate pages (similar content, different URLs)
- Flag auto-generated pages with no unique value

Index bloat:
- Estimate indexed page count vs intended indexable pages
- Identify URL parameters generating infinite URL variations
- Check for faceted navigation creating crawl traps
- Flag tag/category/filter pages that dilute crawl budget

### Link Health

Broken links (4xx):
- Crawl internal links and identify 404, 410, and other 4xx responses
- Check external links for broken destinations
- Prioritize by page importance and link location (navigation vs footer vs content)

Redirect chains and loops:
- Identify redirect chains longer than 2 hops
- Detect redirect loops (A -> B -> C -> A)
- Flag 302 (temporary) redirects that should be 301 (permanent)
- Check for mixed HTTP/HTTPS redirects
- Verify redirect targets return 200

### On-Page SEO

Title tags:
- Missing title tags
- Duplicate titles across pages
- Titles too short (<30 chars) or too long (>60 chars)
- Titles missing primary keyword
- Titles with boilerplate patterns (all starting with brand name)

Meta descriptions:
- Missing descriptions
- Duplicate descriptions across pages
- Descriptions too short (<70 chars) or too long (>160 chars)
- Descriptions that do not include a call to action

Heading structure:
- Missing H1 tags
- Multiple H1 tags per page
- Skipped heading levels (H1 -> H3, missing H2)
- H1 duplicated across pages
- H1 not matching page topic or title tag

Canonical URLs:
- Missing canonical tags
- Self-referencing canonicals (correct, verify present)
- Canonical pointing to a non-200 page
- Canonical chains (A canonicalizes to B, B canonicalizes to C)
- Conflicting canonical and noindex on the same page
- HTTP canonical on an HTTPS page (or vice versa)
- Canonical URL mismatch with actual URL (trailing slash, www)

### Structured Data

Validation:
- Parse all JSON-LD, Microdata, and RDFa on each page
- Validate against Google Rich Results Test requirements
- Check for required fields missing per schema type
- Verify data accuracy (prices match displayed prices, ratings match actual)
- Flag deprecated schema types or properties

Common schema issues:
- Organization schema missing logo or sameAs
- Article schema missing author, datePublished, or image
- Product schema missing offers, price, or availability
- BreadcrumbList not matching actual page hierarchy
- FAQ schema on pages without visible FAQ content
- Review/Rating markup without actual user reviews (spam risk)

### Hreflang (Multi-Language Sites)

- Verify bidirectional hreflang tags (if A points to B, B must point to A)
- Check for missing `x-default` tag
- Verify hreflang language-country codes are valid ISO formats
- Check that hreflang URLs return 200 and are canonical
- Flag pages missing from the hreflang set (partial implementations)
- Verify consistency between hreflang tags and on-page language

### Core Web Vitals

Measurement approach:
- Use Lighthouse programmatic API or PageSpeed Insights API for lab data
- Reference Chrome UX Report (CrUX) for field data when available
- Test on both mobile and desktop

Metrics and thresholds:

| Metric | Good | Needs Improvement | Poor |
|--------|------|-------------------|------|
| LCP | <2.5s | 2.5-4.0s | >4.0s |
| INP | <200ms | 200-500ms | >500ms |
| CLS | <0.1 | 0.1-0.25 | >0.25 |
| FCP | <1.8s | 1.8-3.0s | >3.0s |
| TTFB | <800ms | 800-1800ms | >1800ms |

LCP audit items:
- Identify the LCP element on key pages (hero image, heading, video poster)
- Check if LCP resource is preloaded (`<link rel="preload">` or `fetchpriority="high"`)
- Verify LCP image is served in modern format (WebP/AVIF)
- Check for render-blocking CSS/JS delaying LCP
- Measure server response time contribution to LCP

CLS audit items:
- Identify layout shift sources (images without dimensions, injected ads, late-loading fonts)
- Check for `width` and `height` attributes on images and videos
- Verify `font-display: swap` or `optional` is set
- Flag dynamically injected content above the fold without reserved space

INP audit items:
- Identify long tasks (>50ms) in the main thread
- Check for heavy JavaScript execution on interaction
- Flag synchronous layout calculations triggered by user input

### Mobile-Friendliness

- Verify `<meta name="viewport" content="width=device-width, initial-scale=1">`
- Check for content wider than viewport (horizontal scroll)
- Verify tap targets are at least 48x48px with 8px spacing
- Check font sizes are readable without zooming (minimum 16px body)
- Verify no `user-scalable=no` or `maximum-scale=1` (accessibility violation)
- Test key pages at 320px, 375px, and 768px viewport widths

### Image Optimization

- Missing `alt` attributes (accessibility and SEO)
- Oversized images (intrinsic size much larger than display size)
- Images not using modern formats (WebP, AVIF)
- Images without `width` and `height` attributes (CLS contributor)
- Missing `loading="lazy"` on below-fold images
- Missing `fetchpriority="high"` on LCP images
- Large uncompressed images (>200KB for typical content images)

### Internal Linking

Link distribution:
- Pages with very few internal links (isolated content)
- Pages with excessive internal links (>100, dilutes link equity)
- Important pages buried deep in site hierarchy (>3 clicks from homepage)
- Anchor text analysis -- descriptive vs generic ("click here")

PageRank flow:
- Identify pages concentrating most internal link equity
- Flag important pages with low internal link count
- Check for nofollow on internal links (unusual, usually wrong)

### Keyword Cannibalization

- Identify multiple pages targeting the same primary keyword
- Check title tag, H1, and URL overlap across pages
- Flag pages competing for the same search queries
- Recommend consolidation or differentiation strategy

### Page Speed Scoring

- Total page weight per key page type (target: <1.5MB for content pages)
- Number of HTTP requests (target: <50 for initial load)
- JavaScript bundle size (target: <300KB compressed for initial load)
- CSS bundle size (target: <100KB compressed)
- Third-party script impact (tag managers, analytics, ads, chat widgets)
- Unminified CSS/JS files
- Missing compression (gzip/brotli)
- Missing browser caching headers on static assets

## Framework-Specific SEO Checks

### Blazor (.NET 8+)

Rendering mode and prerendering:
- Verify rendering mode on content pages: static SSR is SEO-friendly by default
- Flag pages using `InteractiveWebAssembly` without prerendering (invisible to crawlers)
- Check `InteractiveServer` pages have prerendering enabled (`@rendermode="InteractiveServer"` prerenders by default; verify not disabled)
- Verify `App.razor` or `_Host.cshtml` includes global meta structure (`<head>`, charset, viewport)

Head management:
- Verify `<HeadOutlet>` component is in the root layout (required for meta tag rendering)
- Check `<PageTitle>` usage on all content pages
- Check `<HeadContent>` for meta descriptions, OG tags, canonical URLs on content pages
- Verify `<base href="/">` tag is present

Static assets:
- Verify `robots.txt` exists in `wwwroot/`
- Verify `sitemap.xml` exists in `wwwroot/` or served via middleware
- Check `wwwroot/favicon.ico` is present

### Next.js

- Verify `generateMetadata` or `metadata` export on all pages
- Check for client-only pages that should be SSR/SSG
- Verify `next/image` usage with proper sizing
- Check `robots.ts` and `sitemap.ts` are configured
- Verify ISR revalidation times are appropriate
- Check for missing `alt` on `Image` components

### Nuxt

- Verify `useHead()` or `useSeoMeta()` on all pages
- Check `nuxt.config.ts` for SSR configuration
- Verify `@nuxtjs/robots` and `@nuxtjs/sitemap` modules
- Check for `NuxtImg` usage with proper optimization

### SvelteKit

- Verify `<svelte:head>` usage on content pages for title, meta, OG tags
- Check `+page.server.ts` for SSR data loading (vs client-only `+page.ts` which runs in browser)
- Verify `export const prerender = true` on static content pages
- Check `+layout.svelte` for global meta structure (charset, viewport, base styles)
- Verify `handle` hook in `hooks.server.ts` sets security/SEO headers (CSP, X-Frame-Options)
- Check `static/robots.txt` and sitemap generation

### Angular SSR

- Verify Angular SSR (`@angular/ssr`) is configured for content pages
- Check `provideClientHydration()` is in app config (prevents content flicker)
- Verify `Title` and `Meta` services set route-level metadata (via resolvers or `Route.title`)
- Check `provideRouter` includes `withInMemoryScrolling` for proper scroll restoration
- Verify `TransferState` prevents duplicate API calls between server and client
- Check prerendered routes list covers all static content
- Flag components using `isPlatformBrowser` to conditionally render -- SEO-visible content must be in the SSR path
- Verify `nguniversal` migration to built-in `@angular/ssr` if on Angular 17+

### Vue (non-Nuxt)

- Check for `@unhead/vue` or `vue-meta` for head management (title, meta, OG tags)
- Verify SSR is configured if site has content pages needing indexation (Vite SSR, Quasar SSR)
- Flag pure SPA mode for content-heavy pages (invisible to crawlers without SSR/SSG)
- Check `vue-router` routes have meta for title/description
- Verify `robots.txt` and sitemap in `public/` directory

### React (non-Next.js)

- Check for `react-helmet-async` or Remix `meta` function exports for head management
- Verify SSR setup if site has content pages (Vite SSR, Remix, Gatsby)
- Flag pure CRA/Vite SPA for content pages needing indexation (invisible to crawlers)
- Check `public/robots.txt` and sitemap configuration
- Verify Remix `loader` functions provide SSR data for SEO-critical pages

## Audit Workflow

1. Collect target URLs -- homepage, key landing pages, product/category pages, blog
2. Crawl the site -- follow internal links, respect robots.txt, record responses
3. Analyze each page against the audit checklist above
4. Aggregate findings by category and severity
5. Prioritize by impact and effort
6. Produce the structured report

Severity: CRITICAL (security/data/outage) > HIGH (perf/reliability) > MEDIUM (maintainability) > LOW (style).

## Output Format

```
SEO Audit Report
=================

Site:              [URL]
Pages Crawled:     [count]
Audit Date:        [date]

Summary
-------
Critical:  [count] issues
High:      [count] issues
Medium:    [count] issues
Low:       [count] issues

Findings by Category
---------------------

### Crawlability and Indexation
| # | Severity | Issue | Affected URLs | Recommendation |
|---|----------|-------|---------------|----------------|
| 1 | Critical | noindex on /pricing | /pricing | Remove noindex meta tag |

### Link Health
| # | Severity | Issue | Affected URLs | Recommendation |
|---|----------|-------|---------------|----------------|

### On-Page SEO
| # | Severity | Issue | Affected URLs | Recommendation |
|---|----------|-------|---------------|----------------|

### Structured Data
| # | Severity | Issue | Affected URLs | Recommendation |
|---|----------|-------|---------------|----------------|

### Core Web Vitals
| Metric | Mobile | Desktop | Status |
|--------|--------|---------|--------|
| LCP    | 3.2s   | 1.8s    | Needs improvement (mobile) |
| INP    | 150ms  | 80ms    | Good |
| CLS    | 0.15   | 0.05    | Needs improvement (mobile) |

### Image Optimization
| # | Severity | Issue | Affected URLs | Recommendation |
|---|----------|-------|---------------|----------------|

### Internal Linking
| # | Severity | Issue | Affected URLs | Recommendation |
|---|----------|-------|---------------|----------------|

Top 10 Priority Fixes
----------------------
1. [Critical] Fix noindex on /pricing -- immediate revenue impact
2. [Critical] Resolve redirect loop on /old-product -> /new-product
...

Crawl Budget Optimization
--------------------------
- Estimated indexable pages: [count]
- Pages blocked by robots.txt: [count]
- Noindex pages: [count]
- Redirect pages: [count]
- Recommendation: [specific advice]
```

## Rules

- Read-only analysis -- never modify site files, configuration, or content
- Report facts with evidence (URLs, status codes, measurements) -- not opinions
- Prioritize findings by business impact, not just technical severity
- Include specific affected URLs for every finding
- Include actionable fix recommendations for every issue
- Group related issues (e.g., all missing alt texts as one finding with a URL list)
- Test both mobile and desktop for Core Web Vitals
- Note framework-specific considerations when applicable
- Flag false positives clearly when a finding may be intentional

## Done Criteria

- All audit categories covered: crawlability, links, on-page, structured data, vitals, images, internal linking
- Every finding has a severity level, affected URLs, and fix recommendation
- Core Web Vitals measured on mobile and desktop for key page types
- Structured data validated against Google Rich Results Test criteria
- Redirect chains and broken links identified with full chain paths
- Canonical URL issues identified with both source and target URLs
- Top 10 priority fixes listed in order of business impact
- Report is actionable -- a developer can take each finding and implement a fix

## Runtime Verification with browser automation

Use **browser automation** to complement static code analysis with runtime checks:
- Navigate to key pages and verify rendered meta tags, Open Graph, and structured data
- Check that canonical URLs resolve correctly
- Verify mobile rendering and viewport configuration
- Measure actual Core Web Vitals scores in a real browser
- Check that redirects resolve as expected
- Verify robots.txt and sitemap.xml accessibility
- Close the browser when audit is complete
