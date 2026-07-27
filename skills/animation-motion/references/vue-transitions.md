# Vue Transitions

Verify the installed Vue/Nuxt line, rendered mode and transition API before implementation.

- Use `<Transition>` for one conditional/switching child and `<TransitionGroup>` for keyed list identity. Select mode from required overlap and focus behavior, not a universal default.
- Name every transitioned CSS property; never use `transition: all`. Coordinate absolute positioning/layout only when container sizing and focus/pointer behavior remain correct.
- JS `enter` and `leave` hooks call `done` only when the installed Vue API and declared hook signature use its asynchronous completion callback; synchronous hooks need no fabricated callback. In both modes, clean timelines/listeners and converge component state on success, reduced motion, error, cancellation and unmount. Cancellation hooks receive only the element, so never invent a completion callback there.
- SSR initial classes and hydration must produce a stable visible state. Route transitions preserve history, focus, scroll and error navigation.
- Test keyed insert/remove/reorder, rapid reversal, nested transitions, preference changes and unsupported browser capabilities.

Official source: [Vue Transition](https://vuejs.org/guide/built-ins/transition.html).
