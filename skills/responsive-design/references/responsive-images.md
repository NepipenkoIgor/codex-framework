# Responsive Image Patterns

## srcset and sizes

```html
<img
  src="/images/hero-800.jpg"
  srcset="
    /images/hero-400.jpg 400w,
    /images/hero-800.jpg 800w,
    /images/hero-1200.jpg 1200w,
    /images/hero-1600.jpg 1600w
  "
  sizes="
    (max-width: 640px) 100vw,
    (max-width: 1024px) 50vw,
    33vw
  "
  alt="Hero image description"
  loading="lazy"
  decoding="async"
/>
```

- `srcset` with `w` descriptors tells the browser which image sizes are available
- `sizes` tells the browser how wide the image will be displayed at each breakpoint
- Browser chooses the best image based on viewport width AND device pixel ratio
- Always provide `alt` text -- empty string for decorative images

## Picture Element for Art Direction

```html
<picture>
  <source media="(min-width: 1024px)" srcset="/images/hero-wide.jpg" />
  <source media="(min-width: 640px)" srcset="/images/hero-medium.jpg" />
  <img src="/images/hero-mobile.jpg" alt="Hero image" loading="lazy" />
</picture>
```

- Use `<picture>` when different crops/compositions are needed at different sizes
- Use `srcset` when the same image just needs different resolutions
- Use `type` attribute for format selection: `<source type="image/avif">`, `<source type="image/webp">`

## Next.js Image

```tsx
import Image from 'next/image';

<Image
  src="/hero.jpg"
  alt="Hero"
  width={1200}
  height={600}
  sizes="(max-width: 768px) 100vw, (max-width: 1200px) 50vw, 33vw"
  priority={false}
  placeholder="blur"
  blurDataURL="data:image/jpeg;base64,..."
/>
```

## Lazy Loading

- Use `loading="lazy"` on all images below the fold
- Use `loading="eager"` (or Next.js `priority`) on above-the-fold hero images
- Use `decoding="async"` to avoid blocking the main thread
- Provide width and height attributes (or aspect-ratio CSS) to prevent layout shift
