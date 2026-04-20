---
name: i18n-implementation
description: Implement internationalization — translation management, locale detection, RTL support, pluralization, date/number formatting, and lazy loading
metadata:
  version: 2.1
  argument-hint: "framework, target locales, translation file format (JSON/YAML/PO), RTL support needed"
---

Implement $ARGUMENTS.


## Non-Negotiable Rules

### Translation Keys and Files

- Every user-facing string goes through the i18n system — zero hardcoded text in templates or components
- Keys are semantic identifiers, never English text: `auth.loginButton` not `Click here to log in`
- Keys use dot notation grouped by feature: `dashboard.metrics.totalRevenue`
- One file per namespace per locale — never combine unrelated features in a single file
- Keep locale files sorted alphabetically by key (reduces merge conflicts)
- Keys are stable once shipped — renaming breaks existing translations and TMS references
- No HTML in translation values — use rich text component patterns for inline markup
- No string concatenation to build sentences — word order varies across languages

### Namespace Conventions

- Namespace boundaries match feature boundaries: `auth`, `dashboard`, `settings`, `errors`, `validation`
- Shared strings in `common` namespace: buttons, labels, navigation, generic actions
- Each route/page loads only its required namespaces — never load all namespaces upfront
- New features get their own namespace from day one — do not dump keys into `common`

### Lazy Loading

- Load only the active locale bundle — never bundle all locales in the main chunk
- Load only namespaces needed for the current route — code-split per namespace
- Cache loaded locale data in memory — no re-fetching on navigation within the same locale
- Each locale namespace file should stay under 50KB — split if larger
- Show fallback content during locale load — never show raw translation keys

### RTL Handling

- CSS logical properties exclusively — no physical `left`/`right`/`margin-left`/`padding-right`
- Set `dir` attribute on `<html>` element dynamically based on current locale
- Directional icons (arrows, progress) must flip in RTL — use `scaleX(-1)` or RTL variants
- Test with real RTL content (Arabic, Hebrew) — not reversed Latin text
- Use Tailwind logical utilities (`ms-*`, `me-*`, `ps-*`, `pe-*`) when Tailwind is available

### Formatting

- All date, number, and currency formatting uses the `Intl` API — never manual string templates
- Use framework-provided formatting wrappers that respect the current locale
- Store dates in UTC — display in user's local timezone
- Never assume all languages have the same text length — design flexible containers

### Type Safety

- Enable type-safe translation keys — catch missing keys at build time, not runtime
- Configure the i18n library's type system from the default locale files
- CI validates all locales have the same key set as the default locale
- CI validates ICU MessageFormat syntax in all locale files
- Block merge if any locale is missing more than the configured threshold of keys

### Pluralization and Interpolation

- Use ICU MessageFormat for all plural logic — never `count === 1` ternaries
- Use named interpolation variables: `{userName}` not `{0}`
- Never split a sentence across multiple translation keys
- Provide translator comments for ambiguous strings

## Implementation Workflow

1. Detect the framework and existing i18n setup in the codebase
2. Choose or confirm the i18n library based on project conventions
3. Set up translation file structure with namespaces matching feature boundaries
4. Configure the i18n provider/module with lazy loading and fallback chain
5. Enable type-safe translation keys from default locale files
6. Implement the language switcher with URL strategy and locale persistence (cookie + localStorage)
7. Add RTL support using CSS logical properties and Tailwind RTL utilities
8. Convert hardcoded strings to translation keys with proper interpolation and ICU pluralization
9. Configure date/number/currency formatting with Intl API through framework wrappers
10. Set up hreflang tags, canonical URLs, and translated SEO metadata per locale
11. Add CI validation: key extraction, completeness check, ICU syntax validation
12. Test with at least one RTL locale and one locale with longer text (e.g., German) to verify layout flexibility

## Output Format

```
i18n Setup:       [library, configuration, provider/module wiring]
Locales:          [supported locales, default locale, fallback chain]
File Structure:   [namespace organization, file naming, directory layout]
URL Strategy:     [path prefix / subdomain / cookie — with routing config]
RTL Support:      [CSS logical properties, Tailwind RTL utilities, dir attribute]
Lazy Loading:     [per-locale + per-namespace code splitting approach]
Type Safety:      [type-safe keys setup, build-time validation]
Formatting:       [date/number/currency via Intl API wrappers]
SEO:              [hreflang tags, canonical URLs, translated metadata, sitemap]
CI Validation:    [key extraction, completeness check, ICU syntax, threshold]
```

Output rules: concrete configuration and implementation code, not abstract guidance; TypeScript types for translation keys when the library supports it; show translation file examples with real key structures; include RTL CSS examples using logical properties; show locale switcher with persistence (cookie + localStorage); handle edge cases: missing translations, locale detection, text expansion, bidirectional text; include CI validation script or config.

## Done Criteria

- All user-facing strings use the i18n system — no hardcoded text
- Translation files organized by namespace with consistent key naming
- Locale switching works without page reload and persists user preference
- RTL layout renders correctly using CSS logical properties
- Date/number/currency formatting uses Intl API through framework helpers
- Locale bundles are lazy-loaded — only active locale is in the main bundle
- SEO tags (hreflang, canonical, translated metadata) are present
- CI validates translation completeness and ICU syntax
- Fallback chain works: missing key in active locale falls back gracefully
- Text expansion is handled — UI does not break with longer translations
