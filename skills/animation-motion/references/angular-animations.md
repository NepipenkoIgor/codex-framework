# Angular Animation Patterns

```typescript
import { trigger, transition, style, animate, query, stagger } from '@angular/animations';

@Component({
  animations: [
    trigger('listAnimation', [
      transition(':enter', [
        query(':enter', [
          style({ opacity: 0, transform: 'translateY(8px)' }),
          stagger(50, [
            animate('200ms ease-out', style({ opacity: 1, transform: 'translateY(0)' })),
          ]),
        ], { optional: true }),
      ]),
    ]),
    trigger('fadeSlide', [
      transition(':enter', [
        style({ opacity: 0, transform: 'translateY(8px)' }),
        animate('200ms ease-out', style({ opacity: 1, transform: 'translateY(0)' })),
      ]),
      transition(':leave', [
        animate('150ms ease-in', style({ opacity: 0, transform: 'translateY(-8px)' })),
      ]),
    ]),
  ],
})
```

## Guidelines

- Use `@angular/animations` for component-level enter/leave and state transitions
- Use Web Animations API (`element.animate()`) for imperative, dynamic animations
- Keep animation trigger definitions in the component metadata -- colocate with the template that uses them
- Prefer CSS transitions for simple hover/focus effects -- Angular animations add bundle weight
