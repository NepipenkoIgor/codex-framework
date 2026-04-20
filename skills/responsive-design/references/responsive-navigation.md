# Responsive Navigation Patterns

## Desktop Sidebar

```html
<nav class="hidden lg:flex lg:w-64 lg:flex-col lg:fixed lg:inset-y-0 border-r">
  <div class="flex-1 overflow-y-auto py-4">
    <!-- Full nav items with labels -->
  </div>
</nav>
<main class="lg:pl-64">
  <!-- Content -->
</main>
```

## Collapsible Sidebar (Icon-Only)

```html
<nav class="hidden md:flex md:w-16 lg:w-64 transition-[width] duration-200">
  <span class="hidden lg:inline">Dashboard</span>
</nav>
```

## Mobile Hamburger / Drawer

```html
<header class="lg:hidden flex items-center justify-between px-4 h-14 border-b">
  <button aria-label="Open menu" aria-expanded="false">
    <MenuIcon />
  </button>
  <Logo />
</header>
<!-- Drawer overlay -->
<div class="lg:hidden fixed inset-0 z-50 bg-black/50" aria-hidden="true">
  <nav class="w-72 h-full bg-white dark:bg-gray-950 overflow-y-auto">
    <!-- Full nav items -->
  </nav>
</div>
```

## Bottom Tab Bar (Mobile Apps)

```html
<nav class="sm:hidden fixed bottom-0 inset-x-0 bg-white dark:bg-gray-950 border-t safe-bottom">
  <div class="flex justify-around py-2">
    <a class="flex flex-col items-center gap-1 text-xs">
      <HomeIcon class="w-5 h-5" />
      <span>Home</span>
    </a>
    <!-- More tabs (max 5) -->
  </div>
</nav>
<main class="sm:pb-0 pb-16"> <!-- Account for bottom bar height -->
  ...
</main>
```

## Responsive Tabs (Overflow Scroll)

```html
<div class="overflow-x-auto scrollbar-none -mx-4 px-4 sm:mx-0 sm:px-0">
  <div class="flex gap-1 min-w-max border-b">
    <button class="px-4 py-2 text-sm whitespace-nowrap">Tab 1</button>
    <button class="px-4 py-2 text-sm whitespace-nowrap">Tab 2</button>
    <!-- Tabs scroll horizontally on mobile -->
  </div>
</div>
```
