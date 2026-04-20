---
name: accessibility-audit
description: Audit frontend code for WCAG 2.2 Level AA accessibility
metadata:
  version: 1.4
  argument-hint: "page URL or component path, WCAG level (A/AA/AAA), audit scope (full page / specific components), framework (React/Vue/Angular/etc)"
---

Audit $ARGUMENTS for WCAG 2.2 compliance. READ-ONLY analysis — findings and fix guidance only, never produce implementation code.

## Tool Integration

- **browser automation**: Use browser navigation and snapshot tools for live WCAG verification, keyboard navigation testing, and contrast ratio checks at runtime.
- **LSP diagnostics**: Use available diagnostics tools to catch accessibility-related TypeScript errors.
- docs lookup tools: Fetch current ARIA specs and WCAG docs on demand.

## Example

A React dashboard component with several accessibility issues:

```tsx
// components/StatusCard.tsx
function StatusCard({ status, onClick }) {
  return (
    <div className="card" onClick={onClick} style={{ color: status === 'error' ? 'red' : '#666' }}>
      <img src="/icon-status.svg" />
      <span className="label">{status}</span>
      <div className="action" onClick={() => navigate('/details')}>View details</div>
    </div>
  );
}
```

Audit findings for this component:

```
[CRITICAL] WCAG 2.1.1 Keyboard — non-interactive element with click handler
File: components/StatusCard.tsx:3
Element: <div className="card" onClick={onClick}>
Issue: div with onClick is not keyboard accessible — no role, tabIndex, or onKeyDown
Impact: keyboard and screen reader users cannot activate this card
Fix: use <button> or add role="button" tabIndex={0} onKeyDown={handleKeyDown}

[HIGH] WCAG 1.1.1 Non-text Content — image without alt text
File: components/StatusCard.tsx:4
Element: <img src="/icon-status.svg" />
Issue: image has no alt attribute — screen readers announce the file name
Impact: blind users hear "icon-status.svg" with no meaningful context
Fix: add alt="Status indicator" or alt="" with aria-hidden="true" if decorative

[HIGH] WCAG 1.4.1 Use of Color — status conveyed by color alone
File: components/StatusCard.tsx:3
Element: inline style color: status === 'error' ? 'red' : '#666'
Issue: error state is indicated only by red text color — no icon, text, or pattern
Impact: color-blind users cannot distinguish error from normal state
Fix: add a visual icon or text prefix like "Error:" alongside the color change

[MEDIUM] WCAG 2.4.4 Link Purpose — ambiguous link text
File: components/StatusCard.tsx:6
Element: <div className="action">View details</div>
Issue: "View details" is repeated across cards without distinguishing context
Impact: screen reader users navigating by links hear identical text with no context
Fix: use aria-label="View details for {status} card" or visually hidden context text
```

## Output

Group findings by severity (highest first), then by WCAG principle. Each: severity, WCAG criterion number+name, file:line, element, issue, affected user groups (blind/low-vision/motor/cognitive), fix with code example. End with estimated WCAG 2.2 AA compliance %, testing recommendations, and positive patterns observed.

## Runtime Accessibility Testing with browser automation

Use **browser automation** to complement code analysis with runtime checks:
- Navigate to audited pages and verify actual rendered DOM structure
- Check focus order by tabbing through interactive elements
- Verify ARIA live regions update correctly during dynamic content changes
- Test color contrast in the rendered page context (accounts for overlays, backgrounds)
- Verify screen reader landmarks and heading hierarchy in rendered output
- Check modal/dialog focus trapping behavior
- Close the browser when verification is complete
