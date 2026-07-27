# Responsive Images

Use this reference when responsive image selection or art direction is in scope. Image processing/security is outside this reference; do not automatically route or load another skill.

1. Measure the rendered slot across actual containers, viewport ranges and DPRs. Express `sizes` from that layout; browser selection cannot repair a false slot declaration.
2. Use `srcset` width descriptors when the rendered slot varies and `sizes` can describe it; density descriptors such as `1x`/`2x` remain valid for a genuinely fixed-size slot. Use `<picture>` only for deliberate art direction or format negotiation. Keep a valid `<img>` fallback, intrinsic dimensions/aspect ratio, and meaningful `alt` (or empty `alt` for decorative content).
3. Do not lazy-load a measured LCP candidate. Do not eagerly load every above-fold candidate. Verify requested resource, emitted markup and network priority in supported browsers.
4. For framework components, use only properties exposed by the installed version. For Next.js specifically, current and pinned lines may differ between `preload`, `priority`, and fetch-priority behavior; consult installed types and [official Image docs](https://nextjs.org/docs/app/api-reference/components/image).
5. Test crop meaning, focal point, localization, forced-colors/high contrast where relevant, failure fallback, layout shift, cache/privacy and actual transferred variants.

Official HTML source: [WHATWG responsive images](https://html.spec.whatwg.org/multipage/images.html#responsive-images).
