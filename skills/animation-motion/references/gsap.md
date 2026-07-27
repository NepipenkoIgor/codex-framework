# GSAP Integration

Use GSAP only when the installed project needs a timeline, gesture or scroll sequence not adequately expressed by CSS/framework primitives. Verify installed plugins, licensing and bundler/CSP compatibility in official GSAP documentation.

- Import modules/plugins explicitly. Never call GSAP through `eval`, string-built code or permissive CSP.
- Scope selectors and timelines to the component; kill timelines, ScrollTriggers, observers and callbacks on interruption/unmount.
- Model reduced motion as a distinct final-state path. Globally accelerating a timeline is not sufficient: it can still flash motion, reorder callbacks or leave lifecycle cleanup timing-dependent.
- Define scroll trigger ownership, refresh on layout changes, and avoid hijacking native scrolling. Capability and input-mode gate nonessential effects.
- Test rapid route changes, detached nodes, background tabs, dynamic content, reduced motion and cleanup with leak/performance evidence.

Official source: [GSAP documentation](https://gsap.com/docs/v3/).
