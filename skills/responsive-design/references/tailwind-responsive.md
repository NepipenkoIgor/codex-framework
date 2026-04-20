# Tailwind Responsive Patterns

## Fluid Typography Config

```js
// tailwind.config.js
module.exports = {
  theme: {
    extend: {
      fontSize: {
        'fluid-sm': 'clamp(0.75rem, 0.7rem + 0.25vw, 0.875rem)',
        'fluid-base': 'clamp(0.875rem, 0.825rem + 0.25vw, 1rem)',
        'fluid-lg': 'clamp(1.125rem, 1rem + 0.625vw, 1.375rem)',
        'fluid-xl': 'clamp(1.25rem, 1rem + 1.25vw, 1.75rem)',
        'fluid-2xl': 'clamp(1.75rem, 1.25rem + 2.5vw, 2.5rem)',
        'fluid-3xl': 'clamp(2rem, 1.25rem + 3.75vw, 3.5rem)',
      },
    },
  },
};
```

## Container Plugin

```js
// tailwind.config.js
module.exports = {
  theme: {
    container: {
      center: true,
      padding: {
        DEFAULT: '1rem',
        sm: '1.5rem',
        lg: '2rem',
      },
      screens: {
        sm: '640px',
        md: '768px',
        lg: '1024px',
        xl: '1280px',
      },
    },
  },
};
```

## Container Queries

```html
<div class="@container">
  <div class="flex flex-col @md:flex-row @md:gap-6 @lg:grid @lg:grid-cols-3">
    ...
  </div>
</div>
```

- Use `@container` Tailwind plugin for container query support in utility classes
- Prefix: `@sm:`, `@md:`, `@lg:`, `@xl:` for container breakpoints
- Container breakpoints are independent of viewport breakpoints

## Responsive Prefixes

```html
<!-- Common responsive patterns -->
<div class="
  grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4
  gap-4 sm:gap-6
  px-4 sm:px-6 lg:px-8
">
```

## Responsive Visibility

```html
<div class="hidden sm:block">Desktop only</div>
<div class="sm:hidden">Mobile only</div>
<div class="hidden md:block lg:hidden">Tablet only</div>
```

- Use `hidden` + responsive `block`/`flex`/`grid` for showing at breakpoints
- Use responsive `hidden` for hiding at breakpoints
- Prefer reflowing content over hiding it -- hidden content is inaccessible

## Print Variant

```html
<nav class="print:hidden">...</nav>
<main class="print:w-full print:max-w-none print:p-0">...</main>
<a class="print:text-black print:underline">Link text</a>
```
