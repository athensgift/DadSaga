# ADR-0049: The Appearance choice is set on the window, not with `preferredColorScheme`

**Status:** Proposed (2026-11-21). The owner reported the bug and confirmed it; the fix waits for the owner's review.
Changes ADR-0030 §"Preferences" (how the root applies the look, and Settings' own copy of it). It takes the fallback
ADR-0030 named for this case, the window's `overrideUserInterfaceStyle`, but sets it from `RootView` rather than from the
app target: `RootView` already holds the choice, and each window gets the look from the view inside it.

## Context
- ADR-0030 has `RootView` apply `.preferredColorScheme(_:)` (`nil` for Automatic), and the Settings sheet apply the
  same value to itself, since Apple documents the scheme as set for "the nearest enclosing presentation".
- On an iPhone in Dark, a dad who opens Settings, picks Light, then Automatic, sees Settings stay light while the screen
  behind it turns dark. Closing and reopening Settings fixes it. Reproduced on the iOS 27.2 simulator with a UI test.
- Removing Settings' copy is not enough: Settings then follows Light and Dark from the root, but going back to `nil`
  still leaves the open sheet in its last look. SwiftUI does not undo a look it gave a presentation once the preference
  becomes `nil`.

## Decision
- `RootView` sets the look on its own window with `.windowAppearance(_:)`: an empty `UIView` in its background sets
  `window.overrideUserInterfaceStyle` (`.unspecified` for Automatic). UIKit passes the window's style to every sheet it
  presents, open or not, and `.unspecified` hands the look back to the iPhone.
- No screen sets `preferredColorScheme` for the dad's choice. Settings' own copy is removed.
- On macOS, where the package is only built to run its tests, the modifier does nothing.
- `DadSagaUITests/SettingsAppearanceTests` checks it: it reads the iPhone's look from home, opens Settings, picks the
  other look, then Automatic, and compares the brightness of the screen each time. It runs in whichever look the
  simulator has, because the iOS 27.2 simulator applies a change of system look only after a reboot. Run it alone with
  `-only-testing:DadSagaUITests/SettingsAppearanceTests` (about a minute) after a change to how the look is applied.
  It covers on the simulator the "Appearance both ways while the sheet is open" check of ADR-0030; the check on a
  device remains.

## Consequences
- Settings, and every other sheet, follows the dad's choice while open, Automatic included, with one source of the look.
- Everything the window presents follows it too: alerts, the keyboard, the share sheet and the Mail compose screen.
  With `preferredColorScheme` most of these did as well; the choice now holds everywhere in the app.
- The domain, the port and the presenters stay as they are (ADR-0030).
- A window opened later (a second scene) gets the look from its own `RootView`.
- Views that draw dark on purpose (the photo viewer, the film renderer) keep setting `\.colorScheme` themselves.
