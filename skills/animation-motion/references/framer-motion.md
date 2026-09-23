# Motion for React

Use this reference only when the repository has selected and pins Motion/Framer Motion. Verify the installed package name, exports and React peer compatibility from lockfile, installed types and official documentation.

- Choose presence/layout/gesture primitives only for a demonstrated need; CSS is sufficient for many state transitions.
- Stable keys represent domain identity. Presence mode, propagation and layout grouping change lifecycle semantics, so derive them from overlap and removal requirements rather than defaults.
- Use the library's reduced-motion capability but still ensure the final visible/removed state, focus restoration and completion callbacks occur when spatial motion is suppressed.
- Cancel subscriptions/controls on unmount and test rapid reversal, nested presence, removed triggers, SSR initial state and hydration.
- Do not freeze spring constants or durations in this skill. Use repository tokens when they exist, otherwise measured interaction requirements; measure representative content.

Official source: [Motion for React documentation](https://motion.dev/docs/react).
