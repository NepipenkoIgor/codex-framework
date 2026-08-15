# Design-system implementation notes

Load this reference only for the selected installed framework, styling system and primitive family. Verify exact component, theming, SSR, compiler and test APIs from manifests, types/schema and matching official documentation.

## Tokens and themes

- Choose one authoritative token source and distinguish primitive values from semantic roles and component contracts. Generated CSS, code, design-tool exports and documentation need an explicit direction and drift check.
- Add only roles required by approved consumers. Preserve contrast intent, forced colors, high contrast, reduced motion, RTL, localization, zoom/text scaling and platform color-scheme behavior.
- Define theme selection, server rendering, first paint, persistence and system-preference precedence without exposing private user state or creating hydration flashes.
- Migration needs compatibility for unmigrated consumers, deprecation ownership, fallback and removal criteria; do not run two styling/token systems indefinitely.

## Component contract

- Start from native semantics. Define public props/events/slots, accessible name/role/state, keyboard and focus behavior, controlled/uncontrolled ownership, form integration, async/mutation behavior and serialization boundaries.
- Cover the states relevant to the component and its real consumers; do not manufacture every possible variant or default arbitrary tokens merely to fill a catalog.
- Derive element props and ref/slot/composition behavior from the installed framework capability. React ref handling, Angular reactive inputs, Vue model APIs, Svelte runes and framework-specific SSR patterns are version-gated rather than universal recipes.
- Keep volatile framework adapters behind stable consumer contracts. Avoid catch-all prop forwarding that leaks internal or unsafe attributes.

## Documentation and adoption

- Document behavior and decision contracts, not just a prop table. Use representative stories/examples for real variants, failure states, themes, localization and interaction; the repository's component tooling determines syntax.
- Migrate one representative consumer end to end before broad rollout. Compare rendered behavior, accessibility, first paint, CSS/bundle impact and compatibility with unmigrated consumers.
- Visual regression thresholds, viewports, motion duration, spacing scales and breakpoints come from the product/system evidence and test harness, not shared constants.

Verify the relevant repository-supported subset of focused behavior, keyboard/focus and assistive technology, themes/forced colors, SSR/hydration/first paint, responsive/zoom/localization, build/package/tree-shaking, generated-token drift, representative visual snapshots and rollback. State why an omitted dimension is not applicable; do not manufacture unsupported test infrastructure.
