# ADR-0039: Website motion in CSS only

**Status:** Accepted (2026-11-21; proposed 2026-11-20, implemented and merged). The owner asked for a livelier site, with animations on scroll. Extends ADR-0031
(the site still has no JavaScript).

## Context
- The landing page is static. The owner wants it to feel more alive as it scrolls.
- ADR-0031 keeps the site free of JavaScript, and `_headers` enforces it with `script-src 'none'`. A scroll library or
  an `IntersectionObserver` script would mean loosening the CSP and adding code to maintain.
- CSS scroll-driven animations (`animation-timeline: view()` and `scroll()`) are in Chrome and Safari 26, the browsers
  an iPhone audience mostly uses. A browser without them ignores the rules inside `@supports`.
- The app respects Reduce Motion everywhere (ADR-0033), and the site says so. The product is calm by design (ADR-0006).

## Decision
1. **CSS only**, in `web/assets/site.css`. No JavaScript, and the CSP stays as it is.
2. **Calm motion that runs once.** No loops, no bounces beyond a small pop, nothing that keeps moving while the page is
   still:
   - the hero's lines rise in one after another on load, and the art scales in;
   - below the hero, headings, leads, cards, rules, pills and checks rise into place as they scroll into view, the
     second card of a row a little after the first;
   - the timeline mock fills in row by row, as if the entries were being logged, and each icon pops in;
   - the hero art drifts slower than the page as it scrolls away;
   - cards lift slightly under a pointer (`hover: hover` only).
3. **Everything is inside `@media (prefers-reduced-motion: no-preference)`**, and the scroll-linked parts are also
   inside `@supports (animation-timeline: view())`. With Reduce Motion, or in a browser without scroll-driven
   animations, every element is visible from the start, as before. Nothing is hidden except by an animation.
4. **The header stays at the top** (`position: sticky`) over a frosted copy of the page's background, and gets a
   hairline edge once the page scrolls under it. Anchored sections get a `scroll-margin-top` so the header doesn't
   cover their headings. This applies with or without motion.
5. Reveals animate `translate` and `opacity`, and hovers use `transform`, so the two never override each other.
6. The stylesheet's query string goes to `?v=5`, so visitors with a cached copy get the new rules at once.

## Consequences
- The site feels livelier at no running cost and with no new code to load.
- In a browser without scroll-driven animations, only the load-in and hover motion run. That is acceptable: the page
  was fully static before.
- Every new section of the landing page should be added to the reveal selector, or it will simply appear static.
- Safari's behaviour was not checked here (only Chromium). Check it on an iPhone after the preview deploys.
