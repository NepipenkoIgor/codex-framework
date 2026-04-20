# View Transitions API

## Page Transitions (Same-Document)

```typescript
// Trigger a view transition
document.startViewTransition(() => {
  // Update the DOM (route change, content swap)
  updateContent();
});
```

```css
/* Customize the transition */
::view-transition-old(root) {
  animation: fade-out 200ms ease-in;
}

::view-transition-new(root) {
  animation: fade-in 200ms ease-out;
}

/* Named view transitions for specific elements */
.hero-image {
  view-transition-name: hero;
}

::view-transition-old(hero) {
  animation: scale-down 300ms ease-in-out;
}

::view-transition-new(hero) {
  animation: scale-up 300ms ease-in-out;
}
```

## Cross-Document Transitions (MPA)

```css
/* In the CSS of both pages */
@view-transition {
  navigation: auto;
}

.shared-element {
  view-transition-name: shared;
}
```

## Guidelines

- Use View Transitions for route changes in frameworks that support it
- Next.js: experimental `viewTransition` config or manual `startViewTransition`
- Astro: built-in view transition support with `<ViewTransitions />` component
- Fall back gracefully -- wrap in `if (document.startViewTransition)` check
- Unique `view-transition-name` per element -- duplicates cause the API to skip the transition
