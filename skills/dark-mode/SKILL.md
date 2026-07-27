---
name: dark-mode
description: Implement accessible theme selection, initial rendering and persistence with CSS tokens or the repository's installed styling system. Use for requested theme changes; do not use for design-only color exploration.
metadata:
  owner: codex-framework
  reviewed: "2026-07-26"
  version: 3.0
  argument-hint: "installed Tailwind/styling version, SSR/CSR, themes, persistence and CSP"
---

# Dark Mode

1. Inspect design tokens, installed Tailwind/styling version/config, SSR/hydration, CSP, cookies/storage policy, authentication/profile sync, assets and accessibility tests. Generate project stack context; existing manifests/lockfiles remain authority. For explicitly authorized greenfield setup only, resolve stable/LTS framework/runtime/styling releases from official sources, verify compatibility as one unit, generate manifest/lockfile and make them authoritative.

Before material mutation, resolve exact task-owned targets, owner and write authority/permissions plus a reversible token/config/code rollback; otherwise stop.
2. Model `system`, explicit theme and fallback separately. Accept only allowlisted theme values from cookie, profile, storage or URL; encode cookie attributes and never interpolate arbitrary selectors/classes/HTML.
3. Use semantic tokens at the shared boundary. Preserve intentional brand/image/media colors; do not universally darken/invert images or require every utility to have a `dark:` twin.
4. Tailwind is capability-gated: preserve v3 config/class behavior or v4 CSS/custom-variant behavior exposed by the installed line. Do not mix remembered `darkMode` recipes across generations.
5. Prevent first-paint mismatch with server rendering or a minimal approved bootstrap. Under CSP use the repository's nonce/hash/external-script strategy; never recommend weakening CSP or assume inline script is allowed.
6. Animate only intentional theme-sensitive properties and honor reduced motion. Never use `transition: all`; it can animate layout, visibility and unrelated sensitive states.
7. Verify initial HTML, hydration, system change, explicit override, invalid/tampered persistence, logout/account switch, no-storage/private mode, CSP enforcement, forced-colors/high contrast, contrast/focus, form controls, charts/media and print.

Report theme precedence/state, Tailwind/styling capability evidence, persistence/CSP contract, token/assets changes, verified first paint and accessibility gaps.
