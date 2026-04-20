---
name: datagrid-patterns
description: Data table and grid architecture — pagination strategy, scrolling, sorting, filtering, inline editing, batch operations, column management, and export
metadata:
  version: 2.2
  argument-hint: "row count (100 / 1K / 10K+ rows), required features (edit/batch/export), framework"
---

Design data table architecture for $ARGUMENTS with appropriate performance and feature patterns.


## Table Architecture Choice

Choose based on row count and feature complexity:

| Approach | Best for | Complexity |
|----------|----------|------------|
| Plain HTML + CSS | <100 rows, display-only | Low |
| Headless (TanStack Table) | Custom styling, any framework, 100-10K rows | Medium |
| Full grid (AG Grid) | Enterprise, Excel-like, 10K+ rows, pivoting/grouping | High |
| Framework-native | PrimeNG, MudBlazor, Vuetify, NativeScript | Medium |

Decision matrix:
- <100 rows, simple → HTML table
- Custom styled, moderate interaction → TanStack Table
- Excel-like editing, grouping, pivoting → AG Grid
- Already using component library → use theirs

## Pagination Strategy

| Strategy | Best for | Note |
|----------|----------|------|
| Offset-based | <100K rows, simple use cases | Page 1, 2, 3... |
| Cursor-based | 100K+ rows, real-time data | More scalable, harder to skip |
| No pagination (virtual scroll) | 10K+ rows same session | Render only visible |

## Sorting & Filtering

- **Sorting:** Server-side for API; reset page to 1 on sort change; multi-column support `sort=name:asc,date:desc`
- **Filtering:** Per-column with chips; debounce text 300ms; operators for dates/numbers `filter[amount][gte]=100`
- **Reset:** Button to clear all filters and sorts back to defaults

## Row Selection & Batch Operations

- Checkbox column with "select all on page" + "select all matching filters"
- Confirmation dialog for destructive batch actions
- Progress indicator for long-running operations
- Deselect all after operation completes

## Inline Editing

- Click to enter edit, Enter/blur to save, Escape to cancel
- Show save indicator during mutation
- Revert to original on error
- Disable other row editing while one is saving

## Column Management (Optional)

- Column visibility toggle (checkbox per column)
- Drag-to-reorder columns
- Resize by dragging header edge
- Persist preferences in localStorage per table ID
- "Reset to defaults" button

## Export Options

- **CSV:** With UTF-8 BOM for Excel compatibility
- **Excel:** Formatted, colored headers, proper column widths
- **PDF:** For complex layouts, use server-side rendering
- **Large exports:** Background job → poll for completion → download from presigned URL

## Virtual Scrolling (10K+ rows)

- TanStack Virtual for React, framework-native for others
- Set estimateSize to actual row height
- Use overscan: 5-15 to prevent blank spaces
- Sticky header requires fixed container height

## Responsive Design

- **Desktop:** Horizontal scroll with sticky first column
- **Tablet:** Horizontal scroll, hide non-critical columns
- **Mobile:** Card view per row, one column per card
- Sticky first column on scroll for row context

## Accessibility Requirements

- ARIA roles: `role="grid"`, `role="row"`, `role="columnheader"`, `role="gridcell"`
- Keyboard: Tab/Shift-Tab, arrow keys, Enter to activate, Space to select
- Screen reader: Announce sort changes, filter count, selection count
- `aria-sort` on headers, `aria-rowindex` for virtual rows

## Performance Targets

| Row Count | Strategy | Expected Load |
|-----------|----------|----------------|
| <100 | Render all | <100ms |
| 100-1K | Client pagination | <300ms |
| 1K-10K | Virtual scrolling | <500ms |
| 10K+ | Server-side + virtual | <1s per page |

## Anti-Patterns to Avoid

1. Re-creating column defs on every render (kills virtualization)
2. Select all without confirmation (accidental bulk operations)
3. CSV without BOM (garbled non-ASCII)
4. Not resetting pagination on filter/sort (wrong results)
5. No sticky column on horizontal scroll (lose row context)

## Architecture Done Criteria

- Table library chosen for row count and features
- Pagination strategy decided (offset vs cursor)
- Sorting/filtering architecture clear (client vs server)
- Column management plan (visibility, reorder, resize, persist)
- Inline editing approach (cell or row)
- Batch operation strategy with confirmation
- Export formats decided (CSV, Excel, PDF)
- Virtual scrolling for 10K+ rows
- Responsive strategy for mobile (scroll vs card)
- Accessibility audit planned (ARIA, keyboard, screen reader)

> For extended implementation patterns, ask to invoke `/datagrid-patterns-implement` on demand.
