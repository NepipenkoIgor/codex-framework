# Svelte Transition Patterns

```svelte
<script>
  import { fade, fly, slide, scale, crossfade } from 'svelte/transition';
  import { quintOut } from 'svelte/easing';

  const [send, receive] = crossfade({ duration: 300, fallback: fade });
</script>

{#if visible}
  <div in:fly={{ y: 8, duration: 200, easing: quintOut }} out:fade={{ duration: 150 }}>
    Content
  </div>
{/if}

{#each items as item (item.id)}
  <div
    animate:flip={{ duration: 300 }}
    in:receive={{ key: item.id }}
    out:send={{ key: item.id }}
  >
    {item.name}
  </div>
{/each}
```

## Guidelines

- Use built-in transitions (`fade`, `fly`, `slide`, `scale`) for standard effects
- Use `crossfade` for shared element transitions between lists
- Use `animate:flip` for reorder animations in keyed each blocks
- Create custom transitions for project-specific effects
