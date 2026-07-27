# Responsive Navigation

Use this reference when navigation changes structure or interaction across available space.

- Preserve one logical set of destinations where practical. If two renderings are unavoidable, only one may be interactive/exposed at a time and IDs, state, announcements and focus must not duplicate.
- A disclosure navigation is not automatically an ARIA menu. Prefer native links and a button with accessible name, `aria-expanded`, and `aria-controls`; adopt a menu pattern only when application-menu keyboard semantics are intended.
- Opening an overlay navigation must follow the selected modal or nonmodal contract: background inertness, initial/return focus, Escape and outside-dismiss behavior are not determined by its visual shape.
- Keep the current route, authentication/authorization UI, localization, long labels, zoom, safe-area and virtual-keyboard behavior visible and operable. Client-side hiding never enforces authorization.
- SSR should emit stable navigation semantics. Avoid server breakpoint guesses that produce a different link tree on hydration.
- Test keyboard, screen reader, touch, pointer, orientation, resize while open, route change, history, slow hydration and no-JS fallback.

Official patterns: [WAI disclosure navigation example](https://www.w3.org/WAI/ARIA/apg/patterns/disclosure/examples/disclosure-navigation/) and [modal dialog pattern](https://www.w3.org/WAI/ARIA/apg/patterns/dialog-modal/).
