# Svelte Transitions

Verify the installed Svelte/SvelteKit line and compiler types before using transition, animate, motion or navigation APIs.

- Use keyed identity when Svelte `animate:` reordering or the selected crossfade/shared-transition mechanism requires stable item identity; browser navigation View Transitions use their own capability and naming contract. Decide whether enter/leave are local or coordinated across blocks.
- Reduced motion must render the same final state. Refactor removal, cleanup, focus, callbacks and route completion so correctness never depends on an outro event or visual duration; the reduced-motion path may omit or shorten presentation while executing the same independent lifecycle completion.
- Navigation/View Transition integration is capability-gated and must preserve history, focus, scroll and hydration when unsupported or interrupted.
- Custom transition functions return safe CSS or typed tick behavior; do not interpolate untrusted data into executable CSS and do not use evaluated code.
- Test rapid toggles, keyed reorder, route abort, component destruction, SSR initial markup and runtime preference changes.

Official sources: [Svelte transition](https://svelte.dev/docs/svelte/transition) and [Svelte animate](https://svelte.dev/docs/svelte/animate).
