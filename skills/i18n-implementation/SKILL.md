---
name: i18n-implementation
description: Implement locale routing, translations, formatting, pluralization, directionality and localized metadata using the installed stack. Use when application internationalization behavior is primary; route standalone localized SEO and general accessibility/directionality repairs to their dedicated skills, and do not use for translation-only copywriting.
metadata:
  owner: codex-framework
  reviewed: "2026-09-09"
  version: 2.1
  argument-hint: "locales, routing, installed framework/library, date/time semantics, translation source"
---

# Internationalization Implementation

1. Inspect locale policy, routing/canonical behavior, installed i18n/Intl capabilities, translation pipeline, SSR/hydration, CSP, design directionality and tests. Treat these as required discovery, not facts already established: claim a specific surface was inspected only when the task fixture explicitly supplies that inspection or the current run actually reads it, and keep withheld values unavailable. Preserve existing message format and pins. Before material mutation, resolve exact task-owned targets, owner and write authority/permissions plus a reversible message/route/config rollback.
   For an authorized greenfield project, resolve stable/LTS runtime, framework, and i18n package releases from configured official sources at execution time, reject prereleases unless explicitly requested, verify engine/peer/SSR compatibility, then generate and treat the resulting manifest and lockfile as repository authority. Never substitute a remembered current major.
2. Distinguish an instant from civil date/time. Instants have zone/offset and convert; birthdays/due dates/local calendar values may intentionally remain civil. Parse explicit formats, use IANA zones where applicable and test DST gaps/folds and calendar/number/currency rules.
3. Treat translations as untrusted content. Escape by default, sanitize the narrow allowed markup model, prevent translator-controlled URL/attribute/script injection and never concatenate HTML. Isolate user-provided bidi text with semantic direction/Unicode isolation; reject control-character spoofing where security-sensitive.
4. Use logical properties for flow-relative layout, but preserve intentional physical direction for maps, media controls, timelines, charts, icons and gestures after design review. Test mixed RTL/LTR content and keyboard/focus order.
5. Select message loading/splitting from measured bundle, cache and route usage. Do not impose universal namespaces or byte caps.
6. Locale discovery, persistence, fallback and URL strategy are product decisions. Emit hreflang only for real reciprocal localized public URLs; it is not required for every application route.
7. Verify missing/malformed messages, plural/select branches, long text, locale switch during navigation, SSR hydration, XSS/bidi payloads, DST/civil dates, RTL physical exceptions, screen readers and localized metadata.

Report locale/time/direction contracts, security decisions, installed capability evidence, changed messages/routes, executed checks and untranslated/unsupported risk.
