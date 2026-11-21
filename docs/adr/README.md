# Architecture decision records

One line per ADR, so the relevant ones can be found without reading all of them. The ADRs themselves are never edited
after acceptance ([ADR-0001](0001-record-architecture-decisions.md)); when a later ADR changes part of an earlier one,
this index says so in **Changed by**.

A new ADR adds its row here, and adds itself to **Changed by** on every ADR it supersedes or changes.

| ADR | Decision | Topics | Changed by |
| --- | --- | --- | --- |
| [0001](0001-record-architecture-decisions.md) | Record significant decisions as ADRs | process | |
| [0002](0002-swiftui-ios26-swift6.md) | SwiftUI, iOS 26+, Swift 6 strict concurrency, Swift Testing | stack | |
| [0003](0003-modular-spm-and-xcodegen.md) | One SwiftPM package with a target per layer; project from XcodeGen | build, modules | |
| [0004](0004-offline-first-on-device-data.md) | All child data on device: no account, backend or analytics SDK | privacy, storage, sync | |
| [0005](0005-content-as-data.md) | Game content is bilingual JSON, validated at load | content, localization | 0027 (UI strings), 0048 (an id that has shipped never goes; renames keep it in `formerIDs`) |
| [0006](0006-no-pressure-game-design.md) | No pressure: XP for the dad's actions, no penalties, streaks or deadlines | product rules | 0021 (the dad may delete his own entries) |
| [0007](0007-clean-architecture.md) | Clean Architecture: Domain, Application, Data, Presentation | architecture | 0036 (a presenter may hold a drawing protocol: the film renderer), 0046 (and one that plays sound: the music preview) |
| [0008](0008-hero-classes-and-code-drawn-avatar.md) | Hero classes as content, a code-drawn avatar, the profile in SwiftData | hero, avatar, storage | 0010 (class list), 0026 (store fallback), 0028 (avatar target), 0029 (class look), 0044 (the dad's own hair, beard and glasses) |
| [0009](0009-gitflow.md) | Gitflow: `feature/*` from `develop`, releases on `main` | process, git | |
| [0010](0010-dad-archetype-heroes.md) | Heroes are dad archetypes, not fantasy classes | hero, content | 0029 (class look), 0033 (crest letter) |
| [0011](0011-liquid-glass-and-adaptive-layout.md) | Liquid Glass, system styling, adaptive layout for iPhone Duo | UI, layout | 0030 (developer menu), 0032 (tint values), 0033 (secondary text), 0043 (the fold read as a reserved region; panes above and below it), 0045 (the inner display held upright is split where it folds, not in columns) |
| [0012](0012-families.md) | Up to four children, XP shared by the dad | family, model | 0023 (migration removed), 0030 (family entry) |
| [0013](0013-child-avatars.md) | Child avatars by age stage | avatar, family | |
| [0014](0014-hero-gear.md) | Gear earned from skills and bosses | gear, avatar | 0018 (wardrobe) |
| [0015](0015-legendary-moments.md) | Legendary moments are progress events with a date and a note | moments, progress | |
| [0016](0016-moment-photos.md) | Moment photos as files on device; moments editable and deletable | moments, photos, privacy | 0021 (delete use case), 0022 (photos on every card), 0042 (up to five photos; an edit gives the whole list) |
| [0017](0017-timeline-and-tabs.md) | A timeline tab derived from progress events | timeline, navigation | |
| [0018](0018-wardrobe.md) | Wardrobe: choose what the hero wears per slot | gear, avatar | 0044 (a page in Settings, not a sheet from home) |
| [0019](0019-world-map-and-older-worlds.md) | World map, replayable worlds, worlds up to age 6 | worlds, content | 0044 (the map opens from home's toolbar) |
| [0020](0020-card-tips-and-evergreen-cards.md) | Card tips, evergreen cards, a sibling-only boss | content, cards | |
| [0021](0021-undo-and-delete-entries.md) | Undo and delete the dad's own entries | progress, timeline | 0042 (a first's undo shows in its sheet) |
| [0022](0022-journal-on-every-card.md) | A note and a photo on every card | journal, photos | 0042 (up to five photos) |
| [0023](0023-home-screen-widget.md) | Home-screen widget: weekly quest and latest moment | widget | 0026 (migrations), 0027 (widget strings), 0048 (no fallback folder in a release build), 0050 (a link waits while something saves or an editor holds unsaved changes) |
| [0024](0024-weekly-notification.md) | One gentle weekly notification | notifications, product rules | 0030 (bell button), 0037 (the reminder card waits while a film card shows) |
| [0025](0025-app-icon-and-launch-screen.md) | App icon in Icon Composer, native launch screen | branding | 0033 (also writes the website's images) |
| [0026](0026-versioned-store-and-unavailable-screen.md) | Versioned store with migrations; a calm stop when it can't open | storage, errors | 0034 (widget test before V2), 0042 (V2 and V3 are for photos; `childID` waits for sync), 0048 (the folder is found when the store opens; V5 stores birth days) |
| [0027](0027-ui-string-catalog.md) | UI strings in one shared String Catalog | localization | 0030 (reset wording) |
| [0028](0028-screen-queries-and-hero-art-target.md) | One query per screen, one way to record progress, `HeroArt` target | architecture, modules | 0048 (`Adventure` takes a day, not a calendar) |
| [0029](0029-hero-look-in-content.md) | A hero class names its look in the content | hero, content | |
| [0030](0030-settings-screen.md) | One Settings screen; "start over" for everyone | settings, privacy | 0036 (start over also forgets the film offers), 0044 (a wardrobe row; "Your hero" holds the dad's look and saves at once; the map in home's toolbar), 0048 ("My family" doesn't check the hero; photos a cut-short start over leaves are swept), 0049 (the look is set on the window; Settings no longer sets its own) |
| [0031](0031-website-on-cloudflare-pages.md) | Static website at dadsaga.app on Cloudflare Pages | website, privacy | 0033 (images generated), 0039 (motion in CSS, sticky header), 0040 (own script, tappable family, timeline clip) |
| [0032](0032-contrast-of-tints.md) | Tints readable as text and as fills; the hero keeps its own colours | UI, accessibility, colour | 0033 (its open items) |
| [0033](0033-accessibility-audit-and-secondary-text.md) | Accessibility audit of the main screens, readable secondary text, "D" on the crest | accessibility, testing, colour, hero | 0034 (snapshots at the largest text size, test data for snapshots), 0035 (audit skips, iOS 27.2), 0036 (the audit covers the film sheet), 0037 (a timeline with an entry), 0042 (the photo viewer and a first's second step) |
| [0034](0034-screen-snapshots-pinned-ci-and-store-threads.md) | Screen snapshots, a pinned CI toolchain, the store's work off the main thread | testing, CI, storage, concurrency | 0035 (snapshots get the app's tint), 0036 (film sheet and card snapshots), 0038 (why onboarding's date picker differed by region and by day), 0042 (a first's two steps, the viewer, the timeline with photos) |
| [0035](0035-audit-on-ios-27-shaded-glass.md) | The audit on iOS 27.2: re-measure labels on shaded glass | accessibility, testing | |
| [0036](0036-saga-video.md) | Saga film: drawn frame by frame on the device from the timeline, offered gently, never stored | video, media, product rules, concurrency | 0037 (one offer for the family; what the cards and the sheet show), 0041 (a film with dates gives the age away), 0042 (an entry's further photos, thinned first), 0046 (five bundled tracks, each with a Greek and an English title and mood), 0047 (`FilmKit` aims a camera at a part of a picture; the photos are looked at while the film is made), 0048 (periods and occasions count from a birth day, on the Gregorian calendar), 0052 (every track outlasts the longest film the content allows) |
| [0037](0037-saga-film-drawing-sheet-and-offer.md) | Drawing the saga film in Presentation, its sheet, one offer card for the family | video, architecture, product rules, UI | 0041 (dates on the opening, first and boss cards, behind a switch), 0042 (photos alone include further photos), 0046 (a music choice and a preview on the sheet; the credits name the track in the film's language), 0047 (the glide aims at a photo's subject, a child first, and never cuts it) |
| [0038](0038-date-picker-sized-by-its-date.md) | The date picker is as wide as the date it shows, not as today's | UI, testing, accessibility | |
| [0039](0039-website-motion-in-css.md) | Website motion in CSS only: reveals on scroll, a sticky header, Reduce Motion respected | website, accessibility, motion | 0040 (JavaScript after all; the mock's reveals removed) |
| [0040](0040-website-script-tappable-family-timeline-clip.md) | The website's own script, a family that cheers when tapped, a clip of the real timeline | website, motion, accessibility | |
| [0041](0041-dates-in-the-saga-film.md) | Dates in the saga film, on by default, behind a switch the film sheet remembers | video, product rules, privacy, localization, UI | 0046 (its port also keeps the music choice) |
| [0042](0042-several-photos-viewer-and-firsts-in-two-steps.md) | Up to five photos on every entry, a full-screen photo viewer, firsts recorded first and filled in after | photos, storage, moments, video, accessibility, product rules | 0043 (the cover above the fold in the note editor and on a first's page), 0047 (which further photos fill an entry's places in the film: Vision's rating, never the cover), 0048 (orphan photos swept at launch), 0050 (quest, boss and "My family" ask too; the question never records; «Συνέχισε την επεξεργασία») |
| [0043](0043-panes-above-and-below-the-fold.md) | Panes above and below the fold when iPhone Duo is half-open like a laptop: home, the saga film, the note editor, the quest and boss sheets, a first's page, the wardrobe, the timeline | UI, layout, video, photos | 0045 (home open and upright uses the same two panes; the reader can report a flat fold) |
| [0044](0044-dad-appearance.md) | The dad's own hair, hair colour, beard and glasses on "Your hero", stored in schema V4; the wardrobe in Settings, the world map in home's toolbar | hero, avatar, storage, content, settings, navigation, product rules | |
| [0045](0045-home-in-two-panes-when-open-upright.md) | Home in the same two panes when iPhone Duo is open and upright; two columns only on its side | UI, layout | |
| [0046](0046-choosing-the-saga-films-music.md) | The dad chooses the saga film's music from five original tracks, hears each before choosing, and the sheet remembers his choice | video, media, content, localization, product rules, UI | 0052 (each track at least as long as the longest film, not 95 seconds) |
| [0047](0047-choosing-and-framing-film-photos-on-device.md) | The saga film's photos chosen and framed with Vision, on the device, while the film is made: the camera on the children, up to 1.4; nothing stored, nothing shown | video, photos, privacy, product rules, concurrency | |
| [0048](0048-data-before-testflight.md) | Before TestFlight: a failed save rolls back; a birth date is a day, with one Gregorian age rule (schema V5); no silent new store in release; shipped content ids never go (`formerIDs`); orphan photos swept at launch | storage, errors, content, photos, product rules, concurrency | |
| [0049](0049-appearance-on-the-window.md) | The Appearance choice is set on the window's `overrideUserInterfaceStyle`, so open sheets follow it, Automatic included | settings, UI | |
| [0050](0050-unsaved-changes-on-every-editor.md) | Every editor keeps unsaved changes, a link waits for them, and the question never records | UI, product rules, widget | |
| [0052](0052-saga-music-outlasts-the-longest-film.md) | Every saga track outlasts the longest film the content allows: the five pieces made longer with `Tools/SagaMusic`, checked against the bundled content | video, media, content, testing | |
