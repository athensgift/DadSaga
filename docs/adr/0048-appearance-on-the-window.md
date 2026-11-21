# ADR-0048: The Appearance choice is set on the window, not with `preferredColorScheme`

**Status:** Accepted (2026-11-21). The owner reported the bug and confirmed it. Changes ADR-0030 §"Preferences" (how
the root applies the look, and Settings' own copy of it), taking the fallback ADR-0030 named for this case.

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
  simulator has, because the iOS 27.2 simulator applies a change of system look only after a reboot.

## Consequences
- Settings, and every other sheet, follows the dad's choice while open, Automatic included, with one source of the look.
- The domain, the port and the presenters stay as they are (ADR-0030).
- A window opened later (a second scene) gets the look from its own `RootView`.
- Views that draw dark on purpose (the photo viewer, the film renderer) keep setting `\.colorScheme` themselves.
