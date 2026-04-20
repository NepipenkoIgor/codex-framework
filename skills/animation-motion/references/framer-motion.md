# Framer Motion Patterns (React)

## Basic Animations

```tsx
import { motion } from 'framer-motion';

<motion.div
  initial={{ opacity: 0, y: 8 }}
  animate={{ opacity: 1, y: 0 }}
  transition={{ duration: 0.2, ease: [0, 0, 0.2, 1] }}
>
  Content
</motion.div>
```

## AnimatePresence (Enter/Exit)

```tsx
import { AnimatePresence, motion } from 'framer-motion';

<AnimatePresence mode="wait">
  {isOpen && (
    <motion.div
      key="modal"
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      exit={{ opacity: 0, scale: 0.95 }}
      transition={{ duration: 0.2, ease: [0, 0, 0.2, 1] }}
    >
      Modal content
    </motion.div>
  )}
</AnimatePresence>
```

- Always wrap conditionally rendered animated elements in `AnimatePresence`
- Use `mode="wait"` when one element should exit before the next enters
- Use `mode="popLayout"` for layout-aware exit animations
- Provide unique `key` props for elements that swap

## Layout Animations

```tsx
<motion.div layout layoutId="card-header">
  {isExpanded ? <ExpandedHeader /> : <CollapsedHeader />}
</motion.div>
```

- Use `layout` prop for elements that change size or position
- Use `layoutId` for shared element transitions across components
- Use `LayoutGroup` to scope layout animations and prevent interference
- Layout animations are GPU-accelerated and handle position + size changes

## Gestures

```tsx
<motion.button
  whileHover={{ scale: 1.02, backgroundColor: 'var(--color-primary-hover)' }}
  whileTap={{ scale: 0.97 }}
  transition={{ type: 'spring', stiffness: 400, damping: 25 }}
>
  Click me
</motion.button>
```

- Use `whileHover`, `whileTap`, `whileFocus`, `whileDrag` for interactive states
- Prefer spring physics for gesture responses -- feels more natural than timed easing
- Keep scale changes subtle: 0.97-1.05 range for buttons and cards

## Spring Configuration

```tsx
const springSnappy = { type: 'spring', stiffness: 400, damping: 25 };    // buttons, toggles
const springGentle = { type: 'spring', stiffness: 200, damping: 20 };    // cards, panels
const springBouncy = { type: 'spring', stiffness: 300, damping: 15 };    // playful elements
const springSmooth = { type: 'spring', stiffness: 150, damping: 25 };    // page transitions
```

## Stagger Patterns

```tsx
const containerVariants = {
  hidden: {},
  visible: { transition: { staggerChildren: 0.05, delayChildren: 0.1 } },
};

const itemVariants = {
  hidden: { opacity: 0, y: 8 },
  visible: { opacity: 1, y: 0, transition: { duration: 0.2, ease: [0, 0, 0.2, 1] } },
};

<motion.ul variants={containerVariants} initial="hidden" animate="visible">
  {items.map((item) => (
    <motion.li key={item.id} variants={itemVariants}>{item.name}</motion.li>
  ))}
</motion.ul>
```

## Reduced Motion

```tsx
import { useReducedMotion } from 'framer-motion';

const prefersReducedMotion = useReducedMotion();

<motion.div
  initial={prefersReducedMotion ? { opacity: 0 } : { opacity: 0, y: 8 }}
  animate={{ opacity: 1, y: 0 }}
  transition={{ duration: prefersReducedMotion ? 0.15 : 0.2 }}
/>
```
