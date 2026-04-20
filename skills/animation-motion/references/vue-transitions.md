# Vue Transition Patterns

```vue
<template>
  <Transition name="fade-slide" mode="out-in">
    <component :is="currentView" :key="currentView" />
  </Transition>

  <TransitionGroup name="list" tag="ul">
    <li v-for="item in items" :key="item.id">{{ item.name }}</li>
  </TransitionGroup>
</template>

<style>
.fade-slide-enter-active { transition: opacity 200ms ease-out, transform 200ms ease-out; }
.fade-slide-leave-active { transition: opacity 150ms ease-in, transform 150ms ease-in; }
.fade-slide-enter-from { opacity: 0; transform: translateY(8px); }
.fade-slide-leave-to { opacity: 0; transform: translateY(-8px); }

.list-enter-active { transition: all 200ms ease-out; }
.list-leave-active { transition: all 150ms ease-in; position: absolute; }
.list-move { transition: transform 300ms ease-in-out; }
.list-enter-from, .list-leave-to { opacity: 0; transform: translateY(8px); }
</style>
```

## Guidelines

- Use `<Transition>` for single element enter/leave
- Use `<TransitionGroup>` for list animations with FLIP-based move transitions
- Use `mode="out-in"` when swapping content -- prevents overlap
- Use GSAP with Vue composables for complex timeline animations
