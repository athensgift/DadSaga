# ADR-0027: UI strings in one shared String Catalog

**Status:** Accepted (2026-11-18). Carries out ADR-0005's "UI strings still use String Catalogs", which the code never
did. Replaces the first bullet of ADR-0023 §5; that ADR's catalog for the widget's system strings stays.

## Context
- About 115 UI strings were written in Swift as `text(el:en:)` or `LocalizedText(el:en:).resolved(for:)`, in 18 files of
  Presentation and WidgetPresentation, and the four skill names lived in the Domain (`Skill.title`).
- Home and the widget wrote the same sentences twice (`HomeStrings`, `WidgetStrings`), e.g. the "+15 XP · Care" reward.
- Plurals were `count == 1 ? … : …` branches (times done, unlocks in, world progress, age).
- "BOSS" on boss cards was not translated, and the camera prompt (`NSCameraUsageDescription`) was English only although
  the development region is Greek.
- The widget extension already has `Widget/Localizable.xcstrings` for what the system reads from its bundle (widget name
  and description, intent title and parameters): English keys, explicit el and en values, `extractionState: manual`.
- ViewModels don't import SwiftUI and are tested in Greek and English in one process with an injected `Locale`.
  `String(localized:bundle:locale:)` cannot serve them: its `locale` does not choose the lookup language.
  `LocalizedStringResource.locale` does.
- Content stays JSON with `LocalizedText` (ADR-0005).

## Decision

### 1. One catalog for every presenter string, in its own target
- New package target `Localization`: `Resources/Localizable.xcstrings` and the `Strings` type. It depends on Domain only
  and never imports SwiftUI. Presentation and WidgetPresentation depend on it, so a sentence the app and the widget share
  is one entry. In ADR-0007's terms it belongs to the presenters' ring.
- Two other catalogs exist because the system reads them from a specific bundle: `Widget/Localizable.xcstrings`
  (unchanged) and `App/Resources/InfoPlist.xcstrings` (new: `NSCameraUsageDescription` in el and en).

### 2. Presenters resolve strings through `Strings`
- `Strings(locale:)` is a `Sendable` value. `text(_ key: String.LocalizationValue) -> String` builds a
  `LocalizedStringResource` for the catalog's bundle and resolves it with `String(localized:)`.
- The lookup language is `el` or `en`, chosen by the rule content uses (`LocalizedText.languageCode(for:)`: Greek for
  Greek, English for everything else), so UI and content are never in two languages. Formatting keeps the full locale.
- Debug builds assert when a key is missing from the catalog, naming the key. Release builds show the English key.
- Shared formatting lives next to it: `skill(_:)` and `reward(xp:skill:)`.
- ViewModels and presenters keep `locale: Locale = .current` and hold a `Strings`. Tests keep injecting `el_GR` and
  `en_US`; the existing presenter tests passed unchanged through the migration.
- Xcode's generated string symbols are not used (`swift test` doesn't generate them). Two keys that would generate the
  same symbol are not allowed by the build, so "Level %lld!" is "Level %lld" plus "!".

### 3. Keys and entries
- The key is the English text; each `\(…)` becomes its format specifier: `Int` → `%lld`, `String` → `%@`. Only `Int` and
  `String` values are interpolated.
- Every entry has `extractionState: manual` and explicit `en` and `el` values with state `translated`. The keys are used
  from other modules, so Xcode's extraction cannot see them.
- A value glued to text becomes a placeholder in one key (`New: %@`, `from %@ years`).
- The committed catalog is the file a build leaves behind: after an Xcode build it is unchanged.
- `CatalogTests` checks that every key has Greek and English (both plural forms where it is a plural) and that the Greek
  has the same placeholders as the key.

### 4. Plurals come from the catalog
A count inside a sentence is one key with `one` and `other` variations in both languages. The `count == 1` branches are
deleted.

### 5. Not in the catalog
Content, names the dad typed, numbers and "XP", SF Symbol names, dates and weekday names (Foundation formats them), the
DEBUG developer menu, previews.

### 6. Smaller fixes on the way
- `Skill.title` left the Domain; the skill names are entries.
- "BOSS" is an entry. The owner chose to keep «BOSS» in Greek too, as a game label.
- `WidgetStrings` is deleted. `HomeStrings` wraps `Strings` for home: its sentences built from parts (age, age range,
  world progress, reward, "Defeated · …") and the medical footer.
- `XPBar` takes its VoiceOver label from the presenter instead of an English "Level".

### 7. Build
SwiftPM compiles a String Catalog only with its Swift Build engine (the default from Swift 6.4). CI runs
`swift test --build-system swiftbuild` so it never depends on the runner's default. The app and the widget each embed the
catalog's resource bundle. `swift test` needs Xcode installed, not only the Command Line Tools.

## Consequences
- All UI text is reviewed in one place, in Xcode's catalog editor, and plurals follow each language's rules.
- One more package target and test target.
- New UI text is an English literal at the call site (`strings.text("…")`) plus an entry with el and en.
- A mistyped key shows English; the debug assertion and the Greek tests catch it.
