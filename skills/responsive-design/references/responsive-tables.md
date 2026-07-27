# Responsive Tables

Use this reference for read-oriented tabular data. Interactive composite-grid behavior is outside this reference; if it becomes the primary requested task, stop and route that separate request rather than creating a hidden dependency chain.

- Preserve native table semantics when users need row/column relationships. A horizontally scrollable region can be correct for intrinsically two-dimensional content; label it when needed, make keyboard scrolling possible, keep focus visible, and signal overflow without obscuring cells.
- Do not hide columns by generic priority. Agree which fields may be omitted and provide an accessible way to retrieve them. Authorization and redaction remain server-side.
- A card alternative changes relationships. If used, keep one exposed rendering, preserve row identity/actions/status, avoid duplicate IDs and confirm screen-reader comprehension.
- Sticky headers/columns must survive zoom, text spacing, long content, RTL and focus without covering targets. Virtualization and editing require a separately scoped interactive-grid contract and are not implemented by this read-oriented reference.
- Test intermediate container widths, keyboard scrolling, screen-reader headers, print/export, long localized cells, errors/empty states and browser zoom/reflow exceptions.

Official guidance: [WAI Tables Tutorial](https://www.w3.org/WAI/tutorials/tables/).
