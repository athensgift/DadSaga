# ADR-0077: The development region is English, so the system falls back to the language our own text does

**Status:** Accepted (2026-11-25). Changes ADR-0027 (its Context's "the development region is Greek") and ADR-0023 §5
(the extension's development region, `el`).

## Context
- The app's own text is Greek for Greek and English for every other language (ADR-0027 §2,
  `LocalizedText.languageCode`). That rule reaches only what our code resolves.
- The system picks the rest from the bundle: the permission prompts' reasons, the widget's description,
  `DadSagaPrivacyPolicyURL`, and UIKit's own words inside our screens ("Cancel", the edit menu). When the phone has none
  of the bundle's languages, it takes the development region, which was `el` in both Info.plists. No ADR chose it: the
  app's came with the first `project.yml`, and the widget's copied it.
- Run on 2026-11-25 on iOS 27.2 in the simulator with German as its only language. `Locale.current` is `en_DE`, so our
  text is English, while `preferredLocalizations` is `el`: both permission reasons, the widget's description, the edit
  menu, the share sheet's "Save Video" and UIKit's "Cancel" are Greek, and the privacy policy opens `/el/privacy/`. The
  widget's parameter names are English, the date picker follows `Locale.current`, and what iOS draws itself (the
  prompts' buttons, the photo picker) is German. 1.0 goes to every territory (ADR-0071).

## Decision
1. **The development region is `en`** for the app and the widget (`CFBundleDevelopmentRegion` in `project.yml`), for the
   Xcode project (`developmentLanguage`) and for the package's resource bundles (`defaultLocalization` in
   `Package.swift`). The localizations stay `el` and `en`, and the catalogs' `sourceLanguage` was already `en`.
2. **It follows the rule of ADR-0027 §2.** If the language of "everything else" ever changes, both change together.
3. **`DevelopmentRegionTests` (package, `LocalizationTests`) checks the sources:** both plists' region and the project's
   in `project.yml`, and the package's. The plists are generated and not in the repository, and CI's package tests run
   without generating them, so a test of the plists themselves would need an app-hosted target; the two there are run
   on the Mac and paused, and CI only compiles them (ADR-0034). It also pins which plists `project.yml` generates, so
   a new target's cannot be forgotten.

## Rejected
- **Choosing the language in code** (a fallback for the privacy URL, for the widget's strings): it can't reach the
  permission prompts or UIKit's words, and it hides the cause.
- **Adding `de`, `fr`… with English text:** one entry per language, forever, to say what the region says once.
- **Leaving `CFBundleDevelopmentRegion` out** so XcodeGen writes `$(DEVELOPMENT_LANGUAGE)`: the same result, one step
  further from the line a reader looks for.

## Consequences
- A phone with neither Greek nor English reads English in what the bundle gives. Run on the same simulator with the
  region `en`: `preferredLocalizations` is `en` for German only and for French only, and Greek and English phones are
  as they were. A list with German first is still settled by Greek or English, whichever comes next.
- What iOS draws itself stays in the phone's language.
