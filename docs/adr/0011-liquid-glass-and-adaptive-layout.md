# ADR-0011: Liquid Glass, system styling and an adaptive layout for iPhone Duo

**Status:** Accepted

## Context
The first screens used a custom cream palette, custom buttons and a floating debug button. They looked fine but not
like an iOS 26 app. The app should also run well on iPhone Duo, Apple's foldable, which has a 466×678 pt cover display
and a 669×951 pt inner display.

## Decision
- **Follow the Human Interface Guidelines for Liquid Glass.** Glass belongs to the navigation and control layer, not to
  content:
  - Screens live in `NavigationStack`s, so navigation bars and toolbar buttons are system glass.
  - Primary actions use `.buttonStyle(.glassProminent)` through `PrimaryButton`, pinned with `safeAreaBar` so the
    scroll edge effect fades content under them.
  - Sheets have no custom background, so partial-height sheets render as glass. They close with `Button(role: .close)`.
  - The only custom `glassEffect` is the short-lived celebration badge floating over the hero.
  - Cards stay solid (`secondarySystemGroupedBackground`) because they are content.
- **System semantic colours** for backgrounds and text (`systemGroupedBackground`, `label`, …), so light/dark mode and
  Increase Contrast work like in Apple's apps. Brand colours (accent, XP, boss, legendary) stay as tokens.
- **System text styles** for Dynamic Type; the rounded design only for large display text.
- **Onboarding pushes** the hero step, so it gets the system back button and swipe-back.
- **The developer menu is a toolbar item**, not a floating button.
- **Adaptive layout instead of device checks.** From 600 pt of width, home splits into two equal columns (hero and
  progress | today's quests); below it, one column capped at a readable width. On the Duo's inner display this keeps
  content off the middle of the screen, where it folds. The hero picker is an adaptive grid (2 columns on phones,
  more on the inner display). Landscape is now allowed.

- **Onboarding's Continue button is part of the form**, not a pinned bar: a pinned bar rides on the keyboard and covers
  the fields on the Duo's cover display. The scroll view anchors to the bottom when the keyboard opens.

- **The two-column home has no navigation bar.** A bar collapses (large title) or minimises (iOS 27) with whichever
  column scrolls, which shifts the other column. The title and developer menu sit in the hero column instead.
  `toolbarMinimizationBehavior` would also solve it, but it needs iOS 27 and CI builds with the iOS 26 SDK.

## Verification status
Checked in the simulator on iPhone 17 Pro (portrait and landscape) and on both iPhone Duo displays (cover and inner).

## Consequences
- Less custom styling to maintain, and the app picks up future system design changes for free.
- The cream background is gone; the look is closer to stock iOS.
- `UIHinge` (iOS 27.1) could later react to the Duo being half-open (e.g. a book-style posture). It is not used yet:
  the equal-column layout already avoids the fold without it.
