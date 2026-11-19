# ADR-0033: An accessibility audit of the main screens, readable secondary text, and a "D" on Super Dad's crest

**Status:** Accepted (2026-11-19). The owner asked to finish the accessibility work; chose to audit at the default text
size only (the largest accessibility sizes were checked once by hand, not tested on every run); and chose "D" for the
crest. Changes ADR-0010 (the crest's "Μ"), ADR-0011 (secondary text uses the system colour), ADR-0025 and ADR-0031
(the website's images are copied by hand from the launch images), and closes the open items of ADR-0032.

## Context
- Dynamic Type (ADR-0011 and the pass before ADR-0032) and the tints (ADR-0032) were fixed, but nothing checked a whole
  screen as VoiceOver and the contrast rules see it.
- Xcode's accessibility audit (`performAccessibilityAudit`) needs a UI test target, and the app had none. It also
  needs a known state: the app always opened the dad's real store, photos, defaults and notifications.
- A first run on the main screens found:
  - the system's `secondaryLabel` is 3.3:1 on the light background, below AA (4.5:1). It colours every subtitle,
    tagline and hint, and iOS uses it for section headers and footers, row values and empty states;
  - home's companion line ("Alex · newborn") was drawn in the hero's colour: 3.0:1 for Super Dad, 2.2:1 for Chef Dad;
    the hero picker's checkmark too (ADR-0032 left both open);
  - the "does not replace your paediatrician" notes were 12 pt captions, which the audit measures below AA even in a
    7:1 colour;
  - the crest's "Μ" was a `Text` inside the drawing, so it was read and measured as text;
  - at the accessibility text sizes, wardrobe items were cut short ("Leg-end…") and the world map broke "months"
    mid-word.

## Decision
1. **A UI test target, `DadSagaUITests`,** with one test that walks through onboarding, home, the world map, a quest,
   the wardrobe, settings and the empty timeline and runs the audit on each. Not covered yet: the boss sheet, the
   hero, family and reminder pages, capturing a moment, the journal editor and a timeline with entries. The test
   runs from the `DadSaga` scheme and is not part of CI yet; `CLAUDE.md` lists the command.
2. **UI tests run on data of their own.** `DeviceData` gathers everything the app keeps on the device: the store, the
   photo folder, the app's defaults and the notification scheduler. Launched with `-uiTesting` in a debug build, the
   app gets an in-memory store, a fresh temporary photo folder, a cleared defaults suite of its own and a scheduler
   that does nothing, so a test run never changes the dad's saga, photos, preferences or reminders. Release builds
   have only the live set.
3. **What the audit skips, and why** (in the test, next to the code):
   - `.textClipped` and `.dynamicType`: they flag Form rows, grids and the hero picker that read in full on screen.
     The accessibility sizes were checked by hand at the largest size;
   - for contrast only: disabled controls (WCAG exempts them), text within 44 pt of a bar, and on the hero step the
     strip under the pinned button, where iOS 26 fades scrolled content; scrolled into view, the same text passes;
   - issues with no element: logged, not failed, since there is nothing to point at;
   - the quest sheet is audited at full height, where it is opaque; at half height it is glass over home.
4. **`DSColor.textSecondary` has its own values:** `#58585D` light, `#98989F` dark, and `#48484A` / `#C7C7CC` with
   Increase Contrast. `DSTextContrastTests` checks AA on the plain background and surface, light and dark, with and
   without Increase Contrast. The text iOS draws in its own grey (form headers, footers and row values, an empty
   state's description) is given this colour explicitly; setting it app-wide would also recolour tinted buttons.
5. **Hero colours are for the drawing.** Text and symbols use the interface colours: the companion line is primary
   text, the picker's checkmark the accent.
6. **Safety notes are `subheadline`,** on quests and bosses alike: read at a glance, not fine print.
7. **Super Dad's crest says "D" for Dad,** drawn as a shape (`HeroCrestLetter`), like the rest of the hero. "D" reads
   in both languages; "Μ" only in Greek.
8. **Wardrobe items and world-map tags grow with the text:** the item grid's width is a `@ScaledMetric`, item names
   wrap instead of truncating, and a world's ages and tag stack at the accessibility sizes.
9. **`Tools/LaunchLogo` also writes the website's images:** `super-dad-light/dark.png` and the 1200×630 `og.png`.
   One run after an avatar change updates the launch screen and the site together.

## Consequences
- Secondary text is a little darker in light mode, in the app and on the website (`--text-2`).
- A UI change that breaks a label, a hit region or contrast fails the audit, when it is run. Until CI runs it, that is
  a habit, not a gate.
- The test needs the English UI and a few labels ("Continue", "World map", "Close"); renaming those means updating it.
- The largest text sizes can regress unnoticed between hand checks.
