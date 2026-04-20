---
name: ui-consistency-audit
description: Audit UI code for design system violations — hardcoded colors, inconsistent spacing, mixed typography, non-tokenized styles, inconsistent component variants, broken focus states, and missing accessibility patterns
metadata:
  version: 1.2
  argument-hint: "codebase scope, design system defined (yes/no), primary violations areas"
---

Audit UI consistency for $ARGUMENTS. READ-ONLY — findings only, never produce implementation code.


## Audit Scope

Scan all files matching: `*.tsx`, `*.jsx`, `*.vue`, `*.svelte`, `*.razor`, `*.css`, `*.scss`, `*.module.css`, `*.styled.ts`, `tailwind.config.*`, `theme.*`

## Audit Categories

### 1. Hardcoded Colors

**What to find:**
- Hex values (`#3b82f6`, `#fff`) in component files instead of tokens/variables
- RGB/HSL values inline instead of referencing variables
- Tailwind arbitrary values (`bg-[#custom]`) instead of theme colors
- Opacity values applied inconsistently to the same semantic color

**How to search:**
```
ast-grep -p '#$HEX' --lang tsx
grep -rn 'rgb\|hsl\|#[0-9a-fA-F]' --include='*.tsx' --include='*.jsx' --include='*.vue'
grep -rn 'bg-\[#\|text-\[#\|border-\[#' --include='*.tsx' --include='*.jsx'
```

**Report format:**
```
HARDCODED COLOR: file:line — `bg-[#3b82f6]` → should use `bg-primary` or `var(--color-primary)`
```

### 2. Inconsistent Spacing

**What to find:**
- Mixed spacing values for the same purpose (some cards use `p-4`, others `p-6`, others `p-5`)
- Arbitrary pixel values (`padding: 13px`) not on the spacing scale
- Inconsistent gap between similar list items or form fields
- Different margin/padding for the same component type in different places

**How to search:**
```
ast-grep -p 'className="$$$p-$N$$$"' --lang tsx
grep -rn 'padding:\|margin:\|gap:' --include='*.css' --include='*.scss'
```

**Report format:**
```
SPACING INCONSISTENCY: Button padding varies — file1:20 uses `px-3`, file2:45 uses `px-4`, file3:12 uses `px-5`
RECOMMENDATION: Standardize to `px-3` (sm), `px-4` (md), `px-6` (lg) per size variant
```

### 3. Typography Drift

**What to find:**
- More than 5-6 distinct font sizes in use (sign of no scale)
- Mixed font-size units (px in some places, rem in others)
- Inconsistent line-height for same font size
- Font weight variations for similar elements (some headings `font-semibold`, others `font-bold`)
- Different font families across components

**How to search:**
```
grep -rn 'text-\(xs\|sm\|base\|lg\|xl\|2xl\|3xl\)' --include='*.tsx' | sort | uniq -c | sort -rn
grep -rn 'font-size:' --include='*.css' --include='*.scss' | sort | uniq -c | sort -rn
```

**Report format:**
```
TYPOGRAPHY: 8 distinct font sizes found — scale should have max 6
  text-xs: 23 usages
  text-sm: 89 usages
  text-[13px]: 12 usages ← VIOLATION: arbitrary, should be text-sm or text-xs
  text-base: 45 usages
  text-[15px]: 3 usages ← VIOLATION: arbitrary
```

### 4. Component Height Inconsistency

**What to find:**
- Buttons and Inputs at different heights when placed side-by-side
- Size variants (sm/md/lg) that don't align across component types
- Fixed pixel heights instead of token-based sizing
- Form rows where elements are visually misaligned

**How to search:**
```
grep -rn 'h-8\|h-9\|h-10\|h-11\|h-12' --include='*.tsx' --include='*.jsx'
ast-grep -p 'height: $VALUE' --lang css
```

**Report format:**
```
HEIGHT MISMATCH: Button uses h-10, but Input next to it uses h-9
  Button (file:line): h-10 (40px)
  Input (file:line): h-9 (36px)
  IMPACT: Misaligned form rows
```

### 5. Focus State Violations

**What to find:**
- Components with no visible focus indicator
- Different focus styles across components (ring on buttons, outline on inputs, nothing on cards)
- Focus only on `:focus` instead of `:focus-visible`
- Custom focus colors that don't match the primary color
- Missing focus trap in modals/dialogs

**How to search:**
```
grep -rn 'focus:\|focus-visible:\|:focus' --include='*.tsx' --include='*.css'
ast-grep -p 'outline: none' --lang css  # potential focus removal
```

**Report format:**
```
FOCUS VIOLATION: file:line — `outline: none` without replacement focus style
FOCUS INCONSISTENCY: Buttons use ring-2 ring-blue-500, Inputs use ring-2 ring-primary → should match
MISSING FOCUS: file:line — interactive element has no focus indicator
```

### 6. Hover/Active/Disabled State Gaps

**What to find:**
- Interactive elements missing hover state
- Inconsistent hover behavior (some buttons darken, some lighten, some change bg)
- Missing disabled styling (looks clickable when disabled)
- Disabled elements still responding to clicks (missing `pointer-events: none`)
- Active/pressed state missing or inconsistent

**How to search:**
```
grep -rn 'hover:\|disabled:\|active:' --include='*.tsx'
ast-grep -p 'disabled={$VAR}' --lang tsx  # find disabled prop usage, check for styling
```

### 7. Border Inconsistency

**What to find:**
- Mixed border widths (`border`, `border-2`, `border-[1.5px]`)
- Different border colors for same component type
- Some elements with borders, similar elements without
- Inconsistent border radius across similar components

**How to search:**
```
grep -rn 'border-\|rounded-' --include='*.tsx' | sort | uniq -c | sort -rn
```

### 8. Shadow Inconsistency

**What to find:**
- More than 4-5 distinct shadow values (sign of no shadow scale)
- Arbitrary shadow values (`shadow-[0_2px_8px_rgba(0,0,0,0.1)]`)
- Inconsistent shadow elevation for similar components (some cards `shadow-sm`, others `shadow-md`)

### 9. Dark Mode Violations

**What to find (if dark mode exists):**
- Colors that don't change in dark mode (white text on white bg)
- Hardcoded colors that bypass the dark mode token swap
- Components that look broken in one mode but fine in the other

### 10. Component API Inconsistency

**What to find:**
- Same concept with different prop names (`variant` vs `type` vs `kind` vs `style`)
- Size props named differently (`size="sm"` vs `small` vs `compact`)
- Missing size variants (Button has sm/md/lg but Badge only has md)
- Different default behaviors for similar components

## Audit Process

1. **Token inventory** — find all design tokens (CSS vars, Tailwind config, theme). If none exist, flag as critical.
2. **Component inventory** — list all UI components with their variants and props.
3. **Scan each category** above using ast-grep and grep.
4. **Cross-reference** — verify components use tokens, not hardcoded values.
5. **Measure consistency** — count unique values per property (colors, spacing, fonts). Fewer = better.
6. **Score** — rate each category: Consistent / Minor drift / Major inconsistency / No system.

## Report Format

```
## UI Consistency Audit — [Project Name]

**Score: X/100**

### Critical (must fix — visible user impact)
- [finding with file:line]

### High (design system violations)
- [finding with file:line]

### Medium (drift — works but inconsistent)
- [finding with file:line]

### Info (improvement opportunities)
- [finding with file:line]

### Token Coverage
- Colors: X% tokenized, Y hardcoded values found
- Spacing: X% on scale, Y arbitrary values
- Typography: X sizes in use, Y expected
- Radius: X values, Y expected (4-5)
- Shadows: X values, Y expected (4)

### Component Matrix
| Component | Sizes | States | Focus | Tokens | Score |
|-----------|-------|--------|-------|--------|-------|
| Button    | sm/md/lg | ✓ | ✓ | 80% | B |
| Input     | md only  | partial | ✗ | 60% | D |

### Remediation Plan (prioritized)
1. [highest-impact fix first]
2. [next...]
```

## Anti-Patterns

- Auditing only CSS files — must include component TSX/JSX/Vue/Razor files where classes are applied
- Reporting "use tokens" without specifying WHICH token to use — always suggest the exact replacement
- Ignoring state consistency — same-looking button must behave the same everywhere
- Only checking colors — spacing and typography drift are equally damaging

## Tool Integration

- **ast-grep**: Primary tool for finding patterns in component code. Use over grep for structural matches.
- **browser automation**: Take screenshots to visually confirm reported inconsistencies.
- **Type diagnostics**: Check component prop types for API inconsistency.

Done: ✓ all 10 categories audited ✓ exact file:line references ✓ token coverage measured ✓ component matrix built ✓ prioritized remediation plan ✓ screenshots for visual evidence
