# View Transitions

Use only after checking the target browser and installed framework/router capabilities against current official documentation.

- Feature-detect the relevant same-document or cross-document capability and preserve a direct DOM/navigation fallback with identical URL, history, focus, scroll and final content.
- For same-document transitions, the update callback must own a real state transition, not visual-only duplication. For cross-document transitions, navigation owns the state change and no application update callback is assumed. Handle rejection, aborted navigation, rapid consecutive transitions and DOM or navigation failure according to the selected capability.
- Keep `view-transition-name` unique in the rendered state and remove/disable names when components overlap unexpectedly.
- Reduced motion must suppress nonessential visual travel while the DOM/navigation update and cleanup still complete.
- Avoid placing secrets or private content into unexpected snapshots; confirm framework rendering, CSP and browser capture behavior for sensitive surfaces.

Official sources: [CSS View Transitions specification](https://www.w3.org/TR/css-view-transitions-1/) and [MDN View Transition API](https://developer.mozilla.org/en-US/docs/Web/API/View_Transition_API).
