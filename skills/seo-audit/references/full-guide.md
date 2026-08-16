# SEO audit evidence guide

Use only for the affected templates, markets and platform. This is an evidence checklist, not a collection of universal scoring constants.

## Crawl, response and index signals

For representative and edge URLs record raw status/headers/body, redirects, canonical, robots meta/X-Robots, sitemap membership, hreflang, internal links and rendered DOM. Redirect chains are findings when they create measurable crawl, latency, canonical or reliability harm; no fixed hop count is universally defective.

`robots.txt` controls crawling, not confidentiality or guaranteed deindexing. Verify private content with unauthenticated authorization tests. A blocked URL can still appear without content; reconcile robots, noindex, canonical, redirects, links and sitemap rather than treating one signal as absolute.

Resolve sitemap file and index limits at execution time from the current official protocol and target-engine documentation, cite that dated provenance, and use sitemap indexes whenever the verified limits require them. If current guidance cannot be checked, keep the limit unresolved rather than reusing remembered thresholds. Validate absolute canonical URLs, fetchability, accurate last modification data when supplied, and only preferred indexable URLs.

## Metadata and content

Check missing, duplicated, misleading, templated or visibly truncated titles/descriptions against query intent and rendered search evidence. Character or word-count heuristics can help triage but are not correctness thresholds. A missing description is not automatically a defect when search engines generate an appropriate snippet. H1/title wording need not match exactly.

Inspect visible main content, headings, internal anchor context, media alternatives and structured data. Do not impose a universal minimum word count; thinness is about satisfying intent, originality and evidence. Structured data must match visible content and current eligibility policy; it never guarantees a rich result.

## International URLs

Validate language/region tags, reciprocal alternates, canonical compatibility and accessible locale switching. `x-default` is optional and useful only for a genuine default/selector page. Do not flag its absence universally or force geo/language redirects.

## JavaScript and rendered behavior

Search engines can render JavaScript, but discovery, blocked resources, errors, timing, hydration, client-only metadata/content, infinite scroll and render cost can still affect crawling/indexing. Compare raw response, rendered DOM, browser console/network and available URL-inspection/search evidence. Do not conclude “JavaScript is invisible” or “rendering always makes it equivalent.”

Test links as real crawlable anchors, paginated/faceted states, status/error templates, lazy content/media and behavior without script where relevant. Use the installed framework and deployment adapter; verify version-specific metadata/rendering APIs rather than copying recipes.

## Performance and evidence ranking

Use field data segmented by template/device/market where available, then reproduce with controlled lab traces. Attribute LCP/INP/CLS and crawl/render failures to concrete resources or code. No lab score alone proves ranking impact.

Every finding states affected URL/template population, environment/time, reproduction, raw/rendered/search evidence, confidence, severity/user/search impact, dependency and remediation direction. Source-only hypotheses remain unverified.

When using browser automation, open a task-owned session, record exact URLs and needed evidence, and close only that session. Do not terminate shared browser processes or delete unrelated profiles/downloads.

## Official sources

- Google sitemap limits: `https://developers.google.com/search/docs/crawling-indexing/sitemaps/build-sitemap`
- Google JavaScript SEO: `https://developers.google.com/search/docs/crawling-indexing/javascript/javascript-seo-basics`
- Google robots guidance: `https://developers.google.com/search/docs/crawling-indexing/robots/intro`
- Google snippets/meta descriptions: `https://developers.google.com/search/docs/appearance/snippet`
- Google localized versions: `https://developers.google.com/search/docs/specialty/international/localized-versions`
- Google structured-data policies: `https://developers.google.com/search/docs/appearance/structured-data/sd-policies`

Re-check current official guidance and other target search engines before version-sensitive conclusions.
