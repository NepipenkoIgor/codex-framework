---
name: image-optimization
description: Implement image optimization including modern formats (WebP, AVIF), responsive images with srcset, lazy loading, placeholder strategies (LQIP, blurhash), and CDN integration
metadata:
  version: 1.4
  argument-hint: "image types (photos/icons/graphics), target platforms (web/mobile), format priorities (AVIF/WebP/JPEG)"
---

Implement $ARGUMENTS.

## Tool Integration

- **browser automation** — capture screenshots for visual verification and regression testing

## Format Selection

| Format | Compression | Browser support | Best for |
|--------|-------------|-----------------|----------|
| AVIF | Best (50-70% smaller than JPEG) | Chrome 85+, Firefox 93+, Safari 16.4+ | Photos, gradients, complex images |
| WebP | Great (25-35% smaller than JPEG) | All modern browsers | Universal modern format |
| JPEG | Good baseline | Universal | Fallback for older browsers |
| PNG | Lossless | Universal | Transparency, screenshots, icons |
| SVG | Vector (tiny for simple shapes) | Universal | Icons, logos, illustrations |

Quality settings: AVIF 50-65 | WebP 75-85 | JPEG 75-85 (mozjpeg) | PNG lossless (oxipng)

Decision flow:
1. Icon, logo, or simple illustration? -> SVG
2. Needs transparency? -> WebP (lossy with alpha) or PNG
3. Photo or complex image? -> AVIF with WebP and JPEG fallbacks
4. Thumbnail (<200px)? -> WebP only (AVIF overhead not worth it at small sizes)

## Responsive Images

### srcset + sizes

Use srcset with width descriptors (400w, 800w, 1200w, 1600w) and sizes to match CSS layout widths. `src` serves as fallback. Ensure `sizes` reflects actual responsive breakpoints to avoid downloading oversized variants.

### Art Direction with `<picture>`

Use `<picture>` with `<source>` for format negotiation (AVIF, WebP, JPEG fallback) and media queries for crop variants. Fallback `<img>` serves older browsers.

### Density Descriptors (Fixed-Size)

For fixed CSS sizes (avatars, icons): use 1x, 2x, 3x srcset variants to serve correct DPR. Include width/height to preserve aspect ratio.

## Lazy Loading

```html
<!-- Above the fold: eager (default) -->
<img src="/hero.webp" alt="Hero" width="1200" height="600" loading="eager" fetchpriority="high" />

<!-- Below the fold: lazy -->
<img src="/feature.webp" alt="Feature" width="800" height="400" loading="lazy" decoding="async" />
```

- Never lazy-load above-the-fold images — they are critical for LCP
- Use `fetchpriority="high"` on the LCP image only
- Add `decoding="async"` to non-critical images

### Intersection Observer (Advanced)

For custom fade-in effects: use IntersectionObserver with 200px rootMargin to load before entering viewport. Prefer native `loading="lazy"` when possible.

## Placeholder Strategies

### LQIP (Low-Quality Image Placeholder)

Generate a tiny (20-40px) JPEG at quality 30 and inline as base64 data URL background. With Sharp: `.resize(20).jpeg({ quality: 30 })`.

### Blurhash

Encode at build time: resize to 32x32, extract RGBA, pass to blurhash library. Decode client-side on canvas before image loads. Produces ~20-30 char string placeholder.

### Other Placeholders

**Dominant color:** Extract via Sharp `.stats()` and use as background. **Skeleton:** Use animated pulse div with image aspect ratio.

## CLS Prevention

Every `<img>` must have `width` and `height` attributes — the browser uses them to calculate aspect ratio before load.

```html
<div class="relative w-full aspect-video overflow-hidden rounded-lg">
  <img
    src="/photo.webp"
    alt="Photo"
    class="absolute inset-0 w-full h-full object-cover"
    loading="lazy"
    width="1200"
    height="675"
  />
</div>
```

- Use `aspect-ratio` CSS for fluid containers
- Use `object-fit: cover` for cropped images in fixed containers
- Never allow images to push content down after loading

## LCP Optimization

```html
<head>
  <link
    rel="preload"
    as="image"
    href="/images/hero.webp"
    type="image/webp"
    fetchpriority="high"
    imagesrcset="/images/hero-400.webp 400w, /images/hero-800.webp 800w, /images/hero-1200.webp 1200w"
    imagesizes="100vw"
  />
</head>

<!-- LCP image -->
<img src="/hero.webp" alt="Hero" fetchpriority="high" loading="eager" width="1200" height="600" />
```

LCP checklist:
- Identify LCP element via Chrome DevTools Performance panel
- Preload with `<link rel="preload">` if not in initial HTML
- Never `loading="lazy"` on the LCP image
- Serve in modern format (WebP/AVIF) at appropriate resolution
- Avoid CSS background images for LCP — use `<img>` (preload scanner cannot discover background images)
- Target LCP under 2.5 seconds

## CDN and Image Service Integration

### Cloudinary / imgix

Use URL transforms: `f_auto` (format), `q_auto` (quality), `w_N` (width), `c_fill` (crop), `dpr_auto` (device pixel ratio). Both support dynamic srcset generation with same responsive pattern.

### Self-Hosted with CDN

- Store originals in S3/R2/GCS; serve via CDN (CloudFront, Cloudflare, Fastly)
- Process on upload (build pipeline) or on-the-fly (image proxy)
- Cache headers: `Cache-Control: public, max-age=31536000, immutable` for hashed URLs

## Next.js Image Component

Use `priority` on LCP images only (sets `eager` + `fetchpriority="high"`). Always provide `sizes` prop or Next.js serves full-width. `placeholder="blur"` requires `blurDataURL`. Configure `remotePatterns` and formats in `next.config.js`. Vercel Image Optimization is automatic.

## Build-Time Optimization

### Sharp (Node.js)

Batch-process images at build time: glob source files, resize to breakpoints (400, 800, 1200, 1600), generate WebP (quality 80) and AVIF (quality 60) variants. Use Sharp with `withoutEnlargement: true` to prevent upscaling.

## SVG Optimization

```bash
npx svgo --multipass input.svg -o output.svg
```

Key plugins: removeDoctype, removeComments, removeMetadata, removeEditorsNSData, cleanupIds, removeUselessDefs, convertColors, removeDimensions.

- **Inline:** icons that need CSS styling (`currentColor`), interactive SVGs, critical-path icons
- **External:** large decorative SVGs, illustrations
- **Sprite sheet:** many small icons — bundle as `<svg><symbol>` sprite

Use `<use href="/icons/sprite.svg#icon-name">` to reference inline sprite symbols. Keeps CSS styling with `currentColor`.

## Background Images

Use `image-set()` for format negotiation in CSS. Avoid for LCP elements — preload scanner cannot discover CSS background images.

```css
.hero {
  background-image: url('/images/hero-800.jpg');
  background-image: image-set(
    url('/images/hero-800.avif') type('image/avif'),
    url('/images/hero-800.webp') type('image/webp'),
    url('/images/hero-800.jpg') type('image/jpeg')
  );
  background-size: cover;
  background-position: center;
}

@media (min-width: 1024px) {
  .hero {
    background-image: image-set(
      url('/images/hero-1600.avif') type('image/avif'),
      url('/images/hero-1600.webp') type('image/webp'),
      url('/images/hero-1600.jpg') type('image/jpeg')
    );
  }
}
```

## Accessibility

Alt text rules:
- Every `<img>` must have an `alt` attribute
- Descriptive: describe what the image shows ("Team celebrating product launch", not "image.jpg")
- Decorative images: `alt=""` (empty string, not omitted)
- Never: `alt="image"`, `alt="photo"`, `alt="picture of..."`
- Functional images: describe the action ("Go to homepage", not "Company logo")
- Complex images (charts, diagrams): provide description via `aria-describedby` or adjacent text

```html
<!-- Decorative -->
<img src="/divider.svg" alt="" role="presentation" width="800" height="2" />

<!-- Complex with long description -->
<figure>
  <img src="/architecture.png" alt="System architecture diagram" aria-describedby="arch-desc" width="1000" height="600" />
  <figcaption id="arch-desc">The system consists of three tiers: a React frontend, Node.js API layer, and PostgreSQL database...</figcaption>
</figure>
```

## Performance Budget

| Page type | Total image weight | Largest single image |
|-----------|--------------------|---------------------|
| Landing page | <500KB | <200KB |
| Product page | <800KB | <300KB |
| Blog post | <400KB | <150KB |
| Dashboard | <200KB | <100KB |

Lighthouse budget configuration:
```json
[{
  "resourceSizes": [{ "resourceType": "image", "budget": 500 }],
  "resourceCounts": [{ "resourceType": "image", "budget": 25 }]
}]
```

Monitor: total image weight per page in CI, single image >300KB alert, LCP target <2.5s, CLS target <0.1.

## Anti-Patterns

- Serving original unoptimized uploads directly to users
- Using only JPEG when WebP/AVIF saves 30-70% bandwidth
- Missing `width`/`height` attributes (causes CLS)
- `loading="lazy"` on the LCP image
- No `sizes` attribute — browser downloads largest srcset variant
- Base64 inlining large images (>2KB) — increases HTML size, blocks rendering
- Using `<img>` for icons instead of SVG
- Same image at all viewport sizes
- No CDN for image delivery
- Client-side image resizing instead of server-side/build-time
- CSS background images for LCP elements

## Implementation Workflow

1. Audit: identify LCP image, oversized images, missing lazy loading
2. Set up image processing pipeline (Sharp build script or CDN transforms)
3. Generate modern format variants (AVIF, WebP, JPEG)
4. Add responsive `srcset` and `sizes` to all images
5. Set explicit `width`/`height` on every `<img>`
6. Add `loading="lazy"` to below-fold images; `fetchpriority="high"` to LCP
7. Implement placeholder strategy (blurhash, LQIP, dominant color)
8. Configure CDN caching headers
9. Set up performance budget and monitoring

## Done Criteria

- All images served in modern formats (WebP minimum, AVIF where supported)
- LCP image preloaded with `fetchpriority="high"` and `loading="eager"`
- All below-fold images use `loading="lazy"` with `decoding="async"`
- Every `<img>` has `width` and `height` attributes
- CLS from images is zero (aspect ratios preserved)
- LCP under 2.5 seconds
- Total image weight within performance budget
- Responsive images serve appropriate resolution for device width
- Placeholder strategy prevents blank spaces during load
- CDN configured with proper cache headers for image assets
- Alt text provided for all informative images; decorative images marked with `alt=""`
- SVGs optimized with SVGO and served inline or as sprite
