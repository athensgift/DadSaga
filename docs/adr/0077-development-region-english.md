# ADR-0077: The development region is English, so the system falls back to the language our own text does

**Status:** Accepted (2026-11-25). Changes ADR-0027 (its Context's "the development region is Greek") and ADR-0023 §5
(the extension's development region, `el`).

## Context
- The app's own text is Greek for Greek and English for every other language (ADR-0027 §2,
  `LocalizedText.languageCode`). That rule reaches only what our code resolves.
- The system picks the rest from the bundle: the permission prompts, the widget's name, description and configuration,
  `DadSagaPrivacyPolicyURL`, and the system's own words inside our screens ("Cancel", the pickers). When the phone has
  none of the bundle's languages, it takes the development region, which was `el` in both Info.plists. No ADR chose
  it: it came with the first `project.yml`.
- Run on 2026-11-25 on iOS 27.2 in the simulator with German as its only language: `Locale.current` is `en_DE`, so our
  text is English, while the bundle's `preferredLocalizations` is `el`, both permission texts and UIKit's "Cancel" are
  Greek, and the privacy policy opens `/el/privacy/`. 1.0 goes to every territory (ADR-0071).

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
- A phone with neither language reads English everywhere, as a mixed one did for our own text only. A phone with Greek
  anywhere before English in its list is Greek, and the reverse, as before.
