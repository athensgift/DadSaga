# ADR-0035: The accessibility audit on iOS 27.2, where it misreads shaded glass

**Status:** Accepted (2026-11-19). The owner asked to make the audit pass on iOS 27.2; the cause was found with
`fable-hard`, which the owner asked for. Changes ADR-0033 (what the audit skips, and its simulator) and ADR-0034 (the
snapshots get the app's tint).

## Context
- ADR-0034 left the audit on the iOS 26.0 simulator: on iOS 27.2 it failed contrast on three glass buttons, "Add a
  child" (onboarding), "I did it!" and "Note or photo (optional)" (the quest sheet).
- A first guess, that iOS 27's glass draws the accent lighter, came from a mismeasurement: the screenshots were sRGB
  and were converted to sRGB a second time. Read as they are, a glass label is exactly the tint (`#3755CD`, 6.0:1 on the
  glass) and a prominent fill within one level of it (white on it, 6.4:1). The accent stays as it is.
- The audit failed the same three buttons with a near-black label (about 18:1), and without `.controlSize(.large)`.

## Decision
1. **Cause:** the audit's contrast detector reads five rows across the middle of an element, takes its two most
   frequent exact colours for the ground and the text, and compares them. iOS 27.2 shades a glass fill by a level or
   two of 255 from top to bottom; one row in five lands on a second shade, which outnumbers the label's pixels, so the
   audit compares the fill with itself (1.01–1.02:1) and never reads the label. Shown three ways: the detector's own
   result on each element's screenshot, a minimal screen of stock SwiftUI buttons (every glass text button fails, with
   a black label too, and passes once the label is heavy enough to outnumber the second shade), and a faint label that
   still fails once the exemption below is in.
2. **The audit measures again where it compared a ground with itself** (`UITests/LabelContrast.swift`): on the same
   rows, if its two most frequent colours are shades of one ground (under 1.1:1 apart), the label is the most frequent
   colour that is not, and the issue is a false alarm only if that label reaches AA (4.5:1). Anywhere the audit read
   two different colours, its verdict stands.
3. **The audit runs on iPhone 17 with iOS 27.2,** the simulator the snapshots use. On iOS 26.0 it still passes.
4. **The snapshots draw the screens with the app's tint** (`.tint(DSColor.accent)`, as `RootView` sets it): without
   it their buttons were the system blue.

## Consequences
- A glass button whose label really is too faint still fails the audit.
- The exemption depends on our own measurement, not on the detector staying as it is; if a later iOS draws glass flat
  again, it simply stops applying.
- Measured in the simulator, in light mode at the default text size. The iOS 26.0 runtime installed here is a beta.
- Lesson for colour measurements: read a screenshot's pixels in its own colour space; never convert them again.
