# ADR-0038: A date picker as wide as the date it shows

**Status:** Proposed (2026-11-20). The onboarding snapshot at the largest text size failed the day after it was
recorded, with no change to the code; the cause was found with `fable-hard`, which the owner asked for, while the owner
was away. Changes ADR-0034 (why onboarding's date picker differed between Macs and CI).

## Context
- `onboarding.en-ax5` was recorded on 19 November and failed on every run on the 20th: the child card was 366 pt wide,
  not 360. The fixture pins the date the screen shows (15 June 2026), and it still showed that date.
- Run again with only the app's clock moved (a test-only library put in front of `gettimeofday` and `clock_gettime`
  in the simulator, never committed): on 19 November the old image passed, on the 20th it failed, and on 11 July 2027
  all three onboarding images failed, with the date written "6/15/26".

## Decision
1. **Cause: SwiftUI's `DatePicker` is as wide as today's date, not as the date it shows.** A compact `UIDatePicker`
   only lays out its date, and only then knows its size, in a layout pass in a window. SwiftUI asks it for a size
   earlier, in the same pass, and never again; it gets the size of the picker as it was made: the real today, in the
   device's region, at the current text size. Measured at the largest text size: 327.67 pt on 19 November ("Nov 19,
   2026") and 333.67 pt on the 20th, for a selection that needs 319.33 pt. The picker draws its pill at the trailing
   edge of that frame, so at the default text sizes nothing moves; stacked under its label at the accessibility sizes,
   the frame is wider than the row and pushes the card. When today's date is shorter than the selection, the pill no
   longer fits its frame and iOS writes the date in digits. In the app this shows where a row opens on a date other
   than today, the family page and the date of a first; once the dad picks a date, SwiftUI measures again, correctly.
2. **`DateRow` hosts the `UIDatePicker` itself and works out its size** (`CompactDatePicker`, in
   `Presentation/Shared/DateRow.swift`): the selected date, written as the picker writes it (the abbreviated date in
   the environment's locale, calendar and time zone), measured in the body font at the environment's text size, plus
   the pill's own padding (12 pt at the sides, 7 pt above and below), rounded up to whole pixels, and one pixel more
   so the long form always fits. The picker still draws itself, opens its own calendar and speaks for itself; only
   its frame is ours. Asking `UIDatePicker` instead was tried first and cannot work: inside SwiftUI's layout pass it
   answers with today's width, with or without a forced layout.
3. **Images:** `onboarding.en-ax5` is recorded again (the card is 352 pt wide). The Greek and dark onboarding images
   are unchanged: drawn with the new picker, the dark one is the same pixel for pixel.
4. **A test measures the row** (`SnapshotTests/DatePickerWidthTests.swift`, in the snapshots' suite): in each of
   the three looks, onboarding's picker writes the fixture's date in words and is as wide as its pill, plus the one
   pixel. With SwiftUI's picker it fails in all three, on any day whose date is not exactly as wide as 15 June's. The
   image at the largest text size cannot show this: it ends above the date row.
5. **The fixture's settings pages get its clock too** (`SagaFixture.settingsPages`): the hero, family and reminder
   view models were built with the real one. No image draws those pages yet.

## Consequences
- The date row is the same on any day: checked by running the snapshots with the app's clock on five different days,
  from 19 November 2026 to 16 August 2029. Its width no longer comes from the device's region either; that was not
  run on another region.
- The two paddings and the date's form are iOS's, copied. If a later iOS changes them, the frame is a little too
  wide (harmless) or too narrow, and then the date is written in digits. The test of point 4 fails either way, so it
  shows with the first run on a new Xcode (ADR-0034).
- ADR-0034 gave the snapshots a region of their own because the date picker differed between the Mac and CI. Most
  likely that was this: today's date is "20 Nov 2026" in en_GR and "Nov 20, 2026" in en_US, two widths. The region
  stays pinned; nothing was measured without it.
- Still open: at the largest text size the date under its label is wider than the card's column (320 pt in 310), so
  the card is 5 pt wider than its neighbours on each side; before, it was 9 to 12 pt. Letting the picker take the
  row's width, where iOS then writes the date in digits, would close it; that is a choice about how the date reads.
- The time picker in the reminder settings is still SwiftUI's, and takes its size the same way: possibly the width of
  the time the page was opened at, not of the reminder's time. Not measured, and in no image.
