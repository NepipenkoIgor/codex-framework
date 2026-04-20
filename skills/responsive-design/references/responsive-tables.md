# Responsive Table Patterns

## Horizontal Scroll (Simplest)

```html
<div class="overflow-x-auto -mx-4 sm:mx-0">
  <div class="min-w-[600px] px-4 sm:px-0">
    <table class="w-full">...</table>
  </div>
</div>
```

- Wrap table in scrollable container
- Negative margins on mobile to extend to screen edges
- Add visual indicator (fade or shadow) that content is scrollable

## Card Layout Fallback

```html
<!-- Table on desktop, cards on mobile -->
<div class="hidden sm:block">
  <table>...</table>
</div>
<div class="sm:hidden space-y-3">
  {items.map(item => (
    <div class="border rounded-lg p-4 space-y-2">
      <div class="flex justify-between">
        <span class="font-medium">{item.name}</span>
        <StatusBadge status={item.status} />
      </div>
      <div class="text-sm text-secondary">
        <span>{item.date}</span> · <span>{item.category}</span>
      </div>
    </div>
  ))}
</div>
```

## Column Hiding

```html
<th class="hidden lg:table-cell">Created</th>
<th class="hidden xl:table-cell">Updated</th>
<!-- Always show: Name, Status, Actions -->
```

- Hide non-essential columns at narrower breakpoints
- Always keep: primary identifier, status, actions
- Hide first: dates, descriptions, secondary metadata
- Use `title` attribute or expandable rows for hidden data
