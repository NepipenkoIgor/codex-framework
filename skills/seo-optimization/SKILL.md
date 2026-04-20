---
name: seo-optimization
description: Implement SEO best practices including meta tags, structured data, sitemaps, canonical URLs, Open Graph, and Core Web Vitals optimization
metadata:
  version: 1.5
  argument-hint: "page type (landing/product/blog), target keywords, content strategy, social sharing needs"
---

Implement SEO optimization for $ARGUMENTS with appropriate patterns for the use case.


## Meta Tags

### Essential Tags

```html
<title>Primary Keyword - Secondary Context | Brand</title>
<meta name="description" content="120-160 char description with primary keyword and value proposition." />
<meta name="robots" content="index, follow" />
<link rel="canonical" href="https://example.com/page" />
```

Title rules: 50-60 chars, front-load keyword, unique per page, brand at end.
Description rules: 120-160 chars, include keyword naturally, include CTA, unique per page.

Robots: `noindex, nofollow` for staging/admin/user pages. `nosnippet` to prevent snippets. `noarchive` to prevent caching.

## Open Graph and Twitter Cards

```html
<meta property="og:type" content="website" />
<meta property="og:title" content="Page Title - Brand" />
<meta property="og:description" content="Description for social sharing." />
<meta property="og:image" content="https://example.com/og-image.jpg" />
<meta property="og:image:width" content="1200" />
<meta property="og:image:height" content="630" />
<meta property="og:url" content="https://example.com/page" />
<meta name="twitter:card" content="summary_large_image" />
```

Image: 1200x630px, JPEG/PNG, under 1MB. Generate dynamic OG images for unique content pages.

For articles, add `og:type=article`, `article:published_time`, `article:modified_time`, `article:author`.

## JSON-LD Structured Data

### Organization

```json
{ "@context": "https://schema.org", "@type": "Organization",
  "name": "Company", "url": "https://example.com", "logo": "https://example.com/logo.png",
  "sameAs": ["https://twitter.com/company", "https://linkedin.com/company/name"] }
```

### Breadcrumb

```json
{ "@context": "https://schema.org", "@type": "BreadcrumbList",
  "itemListElement": [
    { "@type": "ListItem", "position": 1, "name": "Home", "item": "https://example.com" },
    { "@type": "ListItem", "position": 2, "name": "Products", "item": "https://example.com/products" }
  ]}
```

### Article

Include: headline, description, image, author (Person), publisher (Organization with logo), datePublished, dateModified, mainEntityOfPage.

### Product

Include: name, description, image, brand, offers (Offer with price, priceCurrency, availability), aggregateRating.

### FAQ

Array of Question objects with acceptedAnswer. Include on pages with FAQ sections.

### SoftwareApplication (SaaS)

Include: name, applicationCategory, operatingSystem, offers (AggregateOffer or per-region Offer objects), aggregateRating.

For multi-locale pricing, use separate Offer objects with `eligibleRegion` per country -- do not use a single AggregateOffer when prices differ by region.

Rules: validate with Google Rich Results Test, one primary schema per page, keep data accurate, use `@id` for cross-referencing.

## Sitemaps

### Dynamic Generation

Generate sitemaps from CMS/DB data. Framework patterns in the Framework-Specific section below.

### Large Sites (50K+ URLs)

Split into sitemap index with chunked sub-sitemaps. Enforce `MAX_URLS_PER_SITEMAP = 50_000` constant in code with pagination.

Rules:
- Max 50,000 URLs per sitemap, max 50MB
- Only canonical URLs -- exclude variants, filtered views, drafts
- Update `lastmod` only when content changes
- Reference in robots.txt: `Sitemap: https://example.com/sitemap.xml`

## Canonical URLs

- Every page must have a self-referencing canonical (absolute URL)
- Resolve duplicates: pagination, query params, trailing slashes, www/non-www, HTTP/HTTPS
- Must point to a 200 response, use preferred domain

## Robots.txt

```
User-agent: *
Allow: /
Disallow: /api/
Disallow: /admin/
Disallow: /auth/
Disallow: /dashboard/
Disallow: /search?
Sitemap: https://example.com/sitemap.xml
```

Never block CSS/JS. Block API routes, admin, auth, internal search (infinite URLs).

## Rendering Strategy (All Frameworks)

| Page type | Strategy | Next.js | Nuxt | Blazor | Angular | SvelteKit | React SPA |
|-----------|----------|---------|------|--------|---------|-----------|-----------|
| Marketing / landing | SSG | `generateStaticParams` | `prerender: true` | Static SSR / `dotnet publish` SSG | prerender routes | `export const prerender = true` | Vite SSR or Remix |
| Blog posts | SSG + revalidate | ISR (`revalidate`) | ISR (`routeRules`) | Static SSR | prerender | prerender + invalidation | Remix loader |
| Product pages | ISR or SSR | ISR / `force-dynamic` | `useFetch` SSR | Static SSR or Interactive Server | SSR with resolver | `+page.server.ts` load | Remix / Vite SSR |
| Dashboard | CSR | `'use client'` | `ssr: false` | Interactive Server/WASM | default SPA | CSR component | default SPA |
| Search results | SSR | `force-dynamic` | SSR default | Interactive Server | SSR | `+page.server.ts` | SSR or CSR |

## Framework-Specific Patterns

### Next.js

`next/head` has no effect in App Router — use `generateMetadata()` or `metadata` export only.

```typescript
export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const product = await db.products.findUnique({ where: { slug: params.slug } });
  if (!product) return { title: 'Not Found' };
  return {
    title: `${product.name} - ${product.category} | Brand`,
    description: product.shortDescription,
    openGraph: { title: product.name, description: product.shortDescription,
      images: [{ url: product.imageUrl, width: 1200, height: 630 }] },
    alternates: { canonical: `https://example.com/products/${product.slug}` },
  };
}
// JSON-LD in page component
<script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
```

Sitemap: `app/sitemap.ts` returning `MetadataRoute.Sitemap`. Use `generateSitemaps()` for large sites.

### Blazor (.NET 8+)

Use Static SSR for content pages (default, best for SEO). Enable prerendering when Interactive mode is required: `@rendermode @(new InteractiveServerRenderMode(prerender: true))`. Use `@attribute [StreamRendering]` for slow-data pages — bots get the initial HTML immediately.

**Meta tags with HeadOutlet:**

```razor
@* In App.razor or _Host.cshtml -- required for head management *@
<HeadOutlet @rendermode="InteractiveServer" />

@* Per-page meta *@
<PageTitle>@_product.Name - Category | Brand</PageTitle>
<HeadContent>
    <meta name="description" content="@_product.Description" />
    <link rel="canonical" href="@_canonicalUrl" />
    <meta property="og:title" content="@_product.Name" />
    <meta property="og:image" content="@_product.ImageUrl" />
    <script type="application/ld+json">@((MarkupString)_jsonLd)</script>
</HeadContent>
```

**Canonical URL generation:**

```csharp
@inject NavigationManager Nav
@code {
    private string _canonicalUrl => Nav.ToAbsoluteUri(Nav.Uri).GetLeftPart(UriPartial.Path);
}
```

**Sitemap:** Middleware endpoint (`/sitemap.xml`) querying DB, or static file in `wwwroot/` for small sites.
**Robots.txt:** Static `wwwroot/robots.txt`. For dynamic rules, use a minimal API endpoint.

### Angular (v17+ with SSR)

Use `@angular/ssr` with `provideClientHydration(withHttpTransferCacheInterceptor())` — prevents duplicate API calls on hydration. Add `prerender: { routesFile: "routes.txt" }` in `angular.json` for static routes.

**Meta and title services:**

```typescript
export class ProductPageComponent {
  private meta = inject(Meta);
  private title = inject(Title);

  ngOnInit() {
    this.title.setTitle(`${this.product.name} | Brand`);
    this.meta.updateTag({ name: 'description', content: this.product.description });
    this.meta.updateTag({ property: 'og:title', content: this.product.name });
    this.meta.updateTag({ property: 'og:image', content: this.product.imageUrl });
  }
}
```

**Route-level meta with resolvers:**

```typescript
export const routes: Routes = [{
  path: 'products/:slug',
  component: ProductPageComponent,
  resolve: { product: productResolver },
  data: { meta: { robots: 'index, follow' } }
}];
```

**Sitemap:** Build-time script from route config or an API endpoint. No built-in generator.

### SvelteKit

**Meta tags with svelte:head:**

```svelte
<svelte:head>
  <title>{product.name} - Category | Brand</title>
  <meta name="description" content={product.description} />
  <meta property="og:title" content={product.name} />
  <link rel="canonical" href={`https://example.com/products/${product.slug}`} />
  {@html `<script type="application/ld+json">${JSON.stringify(jsonLd)}</script>`}
</svelte:head>
```

Use `+page.server.ts` load functions for SSR data. Set site-wide defaults (og:site_name, twitter:card) in `+layout.svelte`. Prerender with `export const prerender = true` in `+page.ts` or across subtrees via `+layout.ts`. Sitemap: `src/routes/sitemap.xml/+server.ts` returning XML. Security and cache-control headers via `handle` hook in `hooks.server.ts`.

### Vue / Nuxt

**Nuxt 3 (recommended for SEO):**

```typescript
// composables in pages or layouts
useSeoMeta({
  title: () => `${product.value.name} | Brand`,
  ogTitle: () => product.value.name,
  description: () => product.value.description,
  ogImage: () => product.value.imageUrl,
});

useHead({
  link: [{ rel: 'canonical', href: `https://example.com/products/${route.params.slug}` }],
  script: [{ type: 'application/ld+json', innerHTML: JSON.stringify(jsonLd) }],
});
```

**Nuxt modules:** `@nuxtjs/robots`, `@nuxtjs/sitemap`, `nuxt-schema-org` (typed JSON-LD via `useSchemaOrg()`).

**ISR:** `routeRules: { '/products/**': { isr: 3600 } }` in `nuxt.config.ts`.

**Vue (non-Nuxt) with `@unhead/vue`:**

```typescript
import { useHead, useSeoMeta } from '@unhead/vue'
useHead({ title: 'Page Title | Brand' })
useSeoMeta({ description: 'Page description', ogTitle: 'Title' })
```

For Vue SPA without SSR: `@unhead/vue` works for social crawlers (JS-executing). For full SEO, use Vite SSR or migrate to Nuxt.

### React (non-Next.js)

**Remix:**

```typescript
export const meta: MetaFunction<typeof loader> = ({ data }) => [
  { title: `${data.product.name} | Brand` },
  { name: 'description', content: data.product.description },
  { property: 'og:title', content: data.product.name },
];
// JSON-LD in component
<script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(jsonLd) }} />
```

Remix handles SSR natively. Use `loader` for data, `meta` export for tags, `links` export for canonical.

**React Router (v7+ with SSR):** Similar to Remix -- uses `loader` and `meta` exports when framework mode is enabled.

**react-helmet-async (SPA or custom SSR):**

```tsx
import { Helmet } from 'react-helmet-async';
<Helmet>
  <title>{product.name} | Brand</title>
  <meta name="description" content={product.description} />
  <link rel="canonical" href={canonicalUrl} />
</Helmet>
```

Wrap app in `<HelmetProvider>`. For SSR, use `HelmetServerState` to extract tags during server render.

**Vite SSR:** Use `vite-plugin-ssr` (now Vike) or manual `entry-server.tsx` / `entry-client.tsx` split. Combine with `react-helmet-async` for meta tag extraction during SSR.

**Sitemap:** Generate at build time with a script, or serve from an API endpoint. No built-in solution -- use `sitemap` npm package.

## Core Web Vitals

| Metric | Good | Poor |
|--------|------|------|
| LCP | <2.5s | >4.0s |
| INP | <200ms | >500ms |
| CLS | <0.1 | >0.25 |

LCP: preload hero images (`fetchpriority="high"`), inline critical CSS, SSR/SSG for above-fold.
CLS: set width/height on images, reserve space for dynamic content, use `aspect-ratio`, `font-display: swap`.
INP: keep handlers <50ms, break long tasks, debounce inputs, `content-visibility: auto`.

## Internationalized SEO (hreflang)

```html
<link rel="alternate" hreflang="en-US" href="https://example.com/en-US/products" />
<link rel="alternate" hreflang="de-DE" href="https://example.com/de-DE/produkte" />
<link rel="alternate" hreflang="x-default" href="https://example.com/products" />
```

Rules:
- Include on every page for every locale, bidirectional
- Use `x-default` for language-neutral version
- ALWAYS use full language-country codes (`en-US`, `de-DE`) when targeting regions -- bare codes (`en`) cause search engines to treat regional variants as interchangeable
- Translate URLs when meaningful
- Generate per-locale sitemaps

## Anti-Patterns

- Client-side only rendering for content pages -- Googlebot may not execute JS reliably
- Infinite URL spaces from search/filter combinations without canonical or noindex -- crawl budget waste
- Sitemap containing non-200 URLs -- signals poor site health to crawlers
- Blazor Interactive WASM without prerendering for content pages -- content invisible until hydration
- Blocking CSS/JS in robots.txt -- Googlebot cannot render pages and may rank them lower

## Output Format

```
Page Type:         [landing / product / blog / category]
Framework:         [Next.js / Nuxt / Blazor / Angular / SvelteKit / React / Vue]
Rendering:         [SSG / ISR / SSR / CSR / Static SSR]
Meta Tags:         [title, description, robots]
Open Graph:        [type, title, description, image]
Structured Data:   [schema type and key properties]
Canonical:         [URL strategy]
Sitemap:           [static / dynamic / index]
Performance:       [LCP, INP, CLS targets]
i18n SEO:          [hreflang configuration]
```

## Done Criteria

- Every indexable page has unique title (50-60 chars) and description (120-160 chars)
- Canonical URLs on all pages (absolute, preferred domain)
- Open Graph and Twitter Card tags with correct image dimensions
- JSON-LD validates in Google Rich Results Test
- Sitemap generated, submitted, referenced in robots.txt
- Robots.txt blocks API/admin/auth, allows CSS/JS
- Content pages server-rendered (SSR/SSG/Static SSR)
- Core Web Vitals pass: LCP <2.5s, INP <200ms, CLS <0.1
- No duplicate content issues
- Hreflang correct for multi-language sites (bidirectional, x-default)
- Framework-specific rendering mode correct for each page type
