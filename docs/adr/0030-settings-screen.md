# ADR-0030: One Settings screen instead of the bell, and "start over" for everyone

**Status:** Accepted (2026-11-19). The owner chose the contents of Settings, how the language row works, and (the same
day) haptics, About, rating and sharing. Replaces the bell button of ADR-0024 §3, the developer menu of ADR-0011, the
"My family from home" entry of ADR-0012 and the "only the developer reset" wording of ADR-0018, ADR-0024 and
ADR-0027 §5. Moves the dad's skin tone out of "My family".

## Context
- Home's toolbar has three buttons: wardrobe, family and a bell for the weekly reminder (ADR-0024). Every new setting
  would need another button.
- The dad can change his hero and skin tone only in onboarding; the skin tone is also on "My family", next to the
  children, where it does not belong. `FamilyViewModel` saves the whole profile, including the hero class it read when
  it opened.
- `DefaultResetProfileUseCase` exists only behind the DEBUG developer menu. It deletes in four separate writes, profile
  first: if a later write failed, onboarding would open on top of the old events, and their XP would count for the new
  saga. It clears notifications by calling the scheduler directly, outside the one reschedule queue of ADR-0024.
- `CFBundleLocalizations` is `el, en`, so iOS already offers a per-app language on the app's page in iOS Settings, and
  every screen follows `Locale.current` (ADR-0027).
- Haptics are played in two places: the celebration overlay on home and the hero's cheer (`HeroAvatar`, in `HeroArt`).
- The generated `Info.plist` says version `1.0`, build `1` (XcodeGen's defaults), not `MARKETING_VERSION` (`0.1.0`).
- There is no way to reach the developer, rate or share the app, or choose light or dark.

## Decision

### 1. A Settings sheet replaces the bell and the family button
A gear button on home (toolbar, and the wide header) opens **Settings** as a sheet with its own `NavigationStack`:

| Section | Row | Does |
|---|---|---|
| Preferences | Language: «Ελληνικά» / "English" | opens the app's page in iOS Settings (§2) |
| | Appearance: Automatic / Light / Dark | a menu picker, applied at once (§3) |
| | Haptics | a switch, on by default (§4) |
| | Weekly reminder | pushes the existing reminder settings (ADR-0024) |
| Hero & family | Your hero | pushes the hero picker (§5) |
| | My family | pushes "My family" |
| Support | Contact us | Mail (§6); hidden without an address |
| | Rate DadSaga | the App Store review page (§6); hidden without an App Store ID |
| | Tell a friend | the share sheet (§6); hidden without an App Store ID |
| About | Version | "0.1.0 (1)" |
| | Privacy policy | opens the policy (§7); hidden without a URL |
| | *(footer)* | the privacy statement (§7) |
| *(last)* | Start over | destructive, with a confirmation (§8) |

- A section with no row to show (Support, until it is configured) is not shown.
- **Family moves into Settings.** It is used a few times a year (a new baby); home keeps what is played with: the
  wardrobe and Settings. Home reloads when the Settings sheet closes, so every change shows.
- `FamilyView` and `ReminderSettingsView` become pushed pages: they lose their own `NavigationStack` and close button.
  "My family" and "Your hero" pop back after saving. Each page's presenter is built once, when its row is tapped
  (`navigationDestination(item:)` with a page enum that compares presenters by identity).

### 2. Language: iOS owns it
- The row shows the current language by the rule UI and content share (`LocalizedText.languageCode`), named in that
  language by Foundation and capitalised: «Ελληνικά» or "English". Tapping it opens
  `UIApplication.openSettingsURLString`. The footer says that iOS restarts DadSaga when the language changes.
- No language is stored in the app. iOS ends the app when its language changes (reported by developers, not documented
  by Apple), and on the next launch everything follows `Locale.current` as today. Notifications already waiting keep the
  old language until the next reschedule, when the app next leaves the screen.
- iOS shows the per-app language only to people with more than one preferred language. `project.yml` sets
  `UIPrefersShowingLanguageSettings: true`, which Apple's WWDC24 session "Build multilingual-ready apps" gives as the way
  to always show it, together with a button that opens the app's settings. Without it, a dad with one preferred
  language would land on a page with no language on it.

### 3. Preferences: one port for how the app looks and feels
- Domain `Preferences` (`appearance: Appearance`, `hapticsEnabled: Bool`; `.default` is `.system` and on). One port,
  `PreferencesRepository` (`fetch`, `save`), and two use cases, `GetPreferencesUseCase` and `SavePreferencesUseCase`.
  A new preference is a new field, not a new port.
- Data `UserDefaultsPreferencesRepository`, in the app's own defaults: one key per field (`preferences.appearance` as
  `system`/`light`/`dark` through an explicit mapping, `preferences.haptics` as a Bool), so a field added later never resets the
  others. Anything missing or unknown reads as the default. The widget does not read it: it follows iOS.
- Preferences belong to the phone, not to the saga: starting over keeps them.
- `RootViewModel` holds them as a display value (`PreferencesChoice`) and reads them before the profile at launch.
  It is the one source of truth: Settings opens with the root's current value and does not read storage. A change is
  shown and passed to the root at once, then stored; saves run one after another, so the store always ends with the
  newest choice. `RootView`
  applies `.preferredColorScheme(_:)` (`nil` for Automatic) and `.environment(\.isHapticsEnabled, …)`. Apple documents
  the colour scheme as set for "the nearest enclosing presentation", so the Settings sheet applies the same value to
  itself.
- The launch screen, and the spinner before the preferences are read, follow iOS. A dad who chose Dark on a light
  iPhone sees a light launch screen first. This is accepted: a launch screen cannot read app settings.
- Greek and English labels reuse the catalog's "Automatic", "Light" and "Dark" («Αυτόματα», «Ανοιχτή», «Σκούρα»): the
  feminine forms agree with «Εμφάνιση» as they do with «απόχρωση», and the English matches iOS's own Display settings.
- **Tokens adapt.** Backgrounds and text are system semantic colours; `accent`, `xp`, `legendary`, `boss` and the hero
  palette are `Color(light:dark:)`, which resolves from the trait the override sets. Not adapting, by design: `heroInk`,
  `heroHighlight`, `heroBlush`, the five `AvatarSkin` tones and one child clothes shade (`0xD9A82E`).
  `LaunchBackground` has a dark variant.
- **Known contrast gap, not fixed here.** `heroHighlight` (white) is the foreground on tinted fills: quest card icon
  tiles, guide step numbers, timeline and world map badges. The dark tints are lighter, so white on dark `accent` is
  about 2.9:1 and on dark `boss` about 2.3:1 (5.7:1 and 5.2:1 in light). White on `legendary` is already about 2.4:1 in
  light. Forcing Dark makes this reachable on a light iPhone. It belongs to the roadmap's accessibility item (an
  on-tint token).

### 4. Haptics: one switch, read where haptics play
- `isHapticsEnabled` is an environment value in `DesignSystem` (default `true`), set once at the root from the
  preferences. The celebration overlay and `HeroAvatar`'s cheer read it. Environment, not display models: `HeroArt` has
  no presenter and must not see Domain or Presentation, and the hero cheers on home, in the wardrobe, in onboarding
  and in the hero picker; one value reaches all of them and every sheet.
- Which haptic a celebration plays stays a Presentation rule with the switch as its input
  (`Celebration.haptic(isEnabled:)` → `.heavy`, `.success` or none). The view only maps the result to
  `SensoryFeedback`, so a test can check that a celebration plays nothing when haptics are off.
- No haptic is added. iOS's own System Haptics switch still applies on top.

### 5. Changing the hero keeps everything
- The hero step of onboarding becomes a shared `HeroPicker` view (skin tone row and the hero grid). Onboarding and the
  new "Your hero" page both use it. "My family" is now only about the children.
- Two edit use cases replace "build a whole profile in the presenter and save it": `UpdateHeroUseCase` (class and skin
  tone) and `UpdateFamilyUseCase` (children). Each reads the stored profile, changes only its own part, validates with
  `ProfileRules` and saves. Neither screen keeps a stale copy of the other's fields. `SaveProfileUseCase` stays for
  onboarding, which creates the profile. The page reads through one query, `GetHeroChoiceUseCase` (ADR-0028).
- **Nothing else changes.** XP, events, moments and photos belong to children and the dad, not to a class. Gear slots
  never clash with any archetype's own items (ADR-0014): the right hand holds the archetype's item, earned items use
  the shoulder, left hand, ground and hip. `Outfit` choices are keyed by skill and item id, never by class. The
  wardrobe stays exactly as it was: no migration, no reset. A test pins this.
- A class is identity only (ADR-0008): changing it is free, unlimited and mentioned nowhere else. The launch image is
  unaffected.

### 6. Support: contact, rate and share, from one configuration spot
- **One place.** Three Info.plist keys sit together, under one comment, in `project.yml`: `DadSagaFeedbackAddress`,
  `DadSagaAppStoreID` and `DadSagaPrivacyPolicyURL`. The owner set the feedback address to `hello@dadsaga.app`, a
  forwarding alias on the app's domain that already exists; the other two stay empty until they exist. `AppContainer` passes the bundle's
  info dictionary and `UIDevice.current.systemVersion` to `AppInfo`, whose initialiser in the package turns them into
  values: an address without "@", an id that is not all digits, or a URL that is not https counts as missing, and its
  row is hidden. Presenters never read the bundle.
- **Real versions.** Both targets set `CFBundleShortVersionString: $(MARKETING_VERSION)` and
  `CFBundleVersion: $(CURRENT_PROJECT_VERSION)`, so About and the mail say "0.1.0 (1)" and the widget's version matches
  the app's, as the App Store requires.
- **Contact us** opens `mailto:` with the subject "DadSaga feedback" (localised) and a body that starts empty and ends
  with `DadSaga 0.1.0 (1) · iOS 26.1`. No child data and no device identifiers (ADR-0004): the dad decides what he
  writes. It opens with SwiftUI's `openURL` and its completion. `canOpenURL` is not used: it needs
  `LSApplicationQueriesSchemes`, and iOS 27 deprecates it ("Prefer attempting to open URLs and handling any failures").
  If nothing opens it, an alert shows the address with a Copy button.
- **Rate DadSaga** opens `https://apps.apple.com/app/id<ID>?action=write-review`, the link from Apple's "Requesting App
  Store reviews". The app never asks for a review by itself (`RequestReviewAction`, `SKStoreReviewController`):
  nothing pops up unasked (ADR-0006).
- **Tell a friend** is a `ShareLink` with `https://apps.apple.com/app/id<ID>`, the subject "DadSaga" and a short message.
  It carries no names, levels or moments.

  | | el | en |
  |---|---|---|
  | Message | Το DadSaga κάνει τα πρώτα χρόνια της πατρότητας παιχνίδι. Εσύ είσαι ο ήρωας και το παιδί σου ο σύντροφός σου. | DadSaga turns the first years of fatherhood into a game. You're the hero, your kid is your companion. |

### 7. About: the version and what happens to the dad's data
- Version and build from `AppInfo`; a privacy policy row only while `DadSagaPrivacyPolicyURL` is set.
- The statement, as the About section's footer:

  | el | en |
  |---|---|
  | Το DadSaga δεν έχει λογαριασμό ούτε παρακολούθηση. Η οικογένεια, οι αποστολές, οι στιγμές και οι φωτογραφίες σου μένουν σε αυτό το iPhone, και στα αντίγραφα ασφαλείας του αν τα κρατάς. | DadSaga has no account and no tracking. Your family, quests, moments and photos stay on this iPhone, and in its backups if you make them. |

- Checked against the code: the store is on-device with `cloudKitDatabase: .none` (ADR-0026); photos are files in the
  App Group container; notifications are local `UNCalendarNotificationTrigger`s; the package has no dependencies and no
  networking code. Mail, rating and sharing leave the app only when the dad taps them. iOS device backups include app
  data, so the statement says so.

### 8. Start over is a real action, and the store goes in one write
- Last row of Settings, in red. A confirmation dialog says plainly what goes, with no counts or levels (no loss
  aversion, ADR-0006):

  | | el | en |
  |---|---|---|
  | Title | Να ξεκινήσεις από την αρχή; | Start over? |
  | Message | Θα διαγραφούν όλα από αυτό το iPhone: η οικογένεια και ο ήρωάς σου, κάθε αποστολή, αφεντικό και στιγμή με τις σημειώσεις και τις φωτογραφίες τους, η ντουλάπα και η εβδομαδιαία υπενθύμιση. Δεν αναιρείται. | Everything will be deleted from this iPhone: your family and hero, every quest, boss and moment with their notes and photos, your wardrobe and the weekly reminder. This can't be undone. |
  | Destructive | Διαγραφή όλων | Delete everything |
  | Cancel | Άκυρο | Cancel |

- `StartOverUseCase` replaces `ResetProfileUseCase`, in this order:
  1. **The store, in one save**, through a new port `SagaEraser` (`eraseAll()`: profile, children, events and outfit
     rows fetched and deleted on one context, then one `save()`). This is the commit point. If it fails, nothing has
     been touched: Settings says so and the dad stays where he was.
  2. The reminder settings.
  3. The pending notifications, **through the app's one `ScheduleWeeklyRemindersUseCase`**, which now finds the reminder
     off and clears them. It runs after any reschedule already under way (leaving the app), so that one can never put
     its notifications back after the clear (ADR-0024 §2).
  4. The notes already shown in Notification Center (`NotificationScheduler.removeDelivered()`): they name the
     children and link to them.
  5. The photos: their folder is removed. If that fails after the store is gone, the start over still completes. The
     files are referenced by nothing, and the next start over removes the whole folder.
- Under the row, a footer: «Διαγράφει τα πάντα σε αυτό το iPhone και ανοίγει ξανά την πρώτη οθόνη.» / "Deletes
  everything on this iPhone and opens the first screen again."
- The dialog title's catalog key "Start over?" would generate the same String Catalog symbol as the row's "Start over",
  which the build rejects. Its entry sets `generatesSymbol: false`: the app looks text up by its English key
  (ADR-0027) and never uses the generated symbols, so the key stays the English text.
- The preferences (§3) stay.
- `ProfileRepository.deleteProfile`, `ProgressRepository.deleteAll` and `OutfitRepository.deleteAll` existed only for
  the developer reset and are removed.
- On success the root switches to onboarding, which closes home, its sheets and the timeline.
- It is the dad's own choice, not something the game does to him, so "nothing is ever lost" (ADR-0006) still holds.
  The can't-open screen (ADR-0026) still offers no reset; Settings is reachable only from home.

### 9. The developer menu goes
Settings covers its only action, for everyone. `DeveloperMenu`, `DeveloperMenuToolbar`, `DeveloperMenuButton`,
`RootViewModel.hasDeveloperMenu`, `restartFromOnboarding` and the `#if DEBUG` in `AppContainer` are deleted. Release
and debug builds wire the same graph. The layout constants that lived in its file move to `Shared/Layout.swift`.

### 10. Where the code goes
| Layer | Adds | Removes |
|---|---|---|
| Domain | `Appearance`, `Preferences` | |
| Application | Ports `PreferencesRepository`, `SagaEraser`; `NotificationScheduler.removeDelivered()`. Use cases `GetPreferencesUseCase`, `SavePreferencesUseCase`, `StartOverUseCase`, `UpdateHeroUseCase`, `UpdateFamilyUseCase`, `GetHeroChoiceUseCase` | `ResetProfileUseCase`, three delete methods |
| Data | `UserDefaultsPreferencesRepository`, `SwiftDataSagaEraser` (opened by `StoreConnection` with the other repositories) | `deleteProfile`, two `deleteAll` |
| DesignSystem | `isHapticsEnabled` environment value | |
| Presentation | `SettingsViewModel`/`SettingsView`, `HeroSettingsViewModel`/`HeroSettingsView`, `HeroPicker`, `PreferencesChoice`, `AppearanceChoice`, `AppInfo`, `SettingsActions`, `SettingsPages`, `SettingsScreens`, `HeroPickerContent`, `Celebration.haptic(isEnabled:)` with `CelebrationHaptic` | developer menu, bell and family buttons, `reminderTitle`, the dad's skin tone on "My family" (`FamilyDraft` keeps it for onboarding) |
| App | The three support keys, the version keys, `UIPrefersShowingLanguageSettings`; wiring | `#if DEBUG` reset |

No stored schema changes: `SchemaV1` and the store fixture are untouched (ADR-0026).

### Deferred
Export and backup (ADR-0004); a sweep of photo files no event references; an on-tint colour token; the privacy
manifest (`PrivacyInfo.xcprivacy`: `UserDefaults` is a required-reason API) before the first TestFlight build; showing
current values on the rows (the hero's name, the reminder's day).

## Verification status
Not yet checked on a device. To check on iPhone 17 Pro and both iPhone Duo displays:
- every row in Greek and English;
- Appearance both ways while the sheet is open, including Dark → Automatic on a light iPhone;
- the language row with a single preferred language (the Language option must be there); the app relaunching in the
  new language; the widget's language afterwards;
- haptics off: no tap on a level-up, on tapping the hero, or on choosing a hero in onboarding;
- Mail with an account (a test mail to `hello@dadsaga.app` arrives), and with Mail deleted (the fallback alert);
- Rate, Tell a friend and Privacy policy hidden while their keys are empty;
- `App/Info.plist` after `xcodegen generate` says 0.1.0 (1);
- start over from a family with photos and a pending notification; then the widget after leaving the app.

## Consequences
- Home has two buttons; new settings have a home.
- A dad can start over without deleting the app, and a failed erase can no longer leave old events under a new family.
- Changing hero is free and keeps the wardrobe; adding a class still needs its drawing (ADR-0029).
- Debug builds lose their one-tap reset; the same action is two taps deeper, in Settings.
- Rating and sharing stay invisible until the app is on the App Store, and the privacy policy until it has a URL,
  with no code change: only `project.yml`.
- If `preferredColorScheme` fails to return to Automatic on a device, the fallback is setting the window's
  `overrideUserInterfaceStyle` from the app target; the domain, port and presenter stay as they are.
