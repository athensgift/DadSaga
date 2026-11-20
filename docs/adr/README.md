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
| [0005](0005-content-as-data.md) | Game content is bilingual JSON, validated at load | content, localization | 0027 (UI strings) |
| [0006](0006-no-pressure-game-design.md) | No pressure: XP for the dad's actions, no penalties, streaks or deadlines | product rules | 0021 (the dad may delete his own entries) |
| [0007](0007-clean-architecture.md) | Clean Architecture: Domain, Application, Data, Presentation | architecture | 0036 (a presenter may hold a drawing protocol: the film renderer) |
| [0008](0008-hero-classes-and-code-drawn-avatar.md) | Hero classes as content, a code-drawn avatar, the profile in SwiftData | hero, avatar, storage | 0010 (class list), 0026 (store fallback), 0028 (avatar target), 0029 (class look) |
| [0009](0009-gitflow.md) | Gitflow: `feature/*` from `develop`, releases on `main` | process, git | |
| [0010](0010-dad-archetype-heroes.md) | Heroes are dad archetypes, not fantasy classes | hero, content | 0029 (class look), 0033 (crest letter) |
| [0011](0011-liquid-glass-and-adaptive-layout.md) | Liquid Glass, system styling, adaptive layout for iPhone Duo | UI, layout | 0030 (developer menu), 0032 (tint values), 0033 (secondary text), 0043 (the fold read as a reserved region; panes above and below it) |
| [0012](0012-families.md) | Up to four children, XP shared by the dad | family, model | 0023 (migration removed), 0030 (family entry) |
| [0013](0013-child-avatars.md) | Child avatars by age stage | avatar, family | |
| [0014](0014-hero-gear.md) | Gear earned from skills and bosses | gear, avatar | 0018 (wardrobe) |
| [0015](0015-legendary-moments.md) | Legendary moments are progress events with a date and a note | moments, progress | |
| [0016](0016-moment-photos.md) | Moment photos as files on device; moments editable and deletable | moments, photos, privacy | 0021 (delete use case), 0022 (photos on every card), 0042 (up to five photos; an edit gives the whole list) |
| [0017](0017-timeline-and-tabs.md) | A timeline tab derived from progress events | timeline, navigation | |
| [0018](0018-wardrobe.md) | Wardrobe: choose what the hero wears per slot | gear, avatar | |
| [0019](0019-world-map-and-older-worlds.md) | World map, replayable worlds, worlds up to age 6 | worlds, content | |
| [0020](0020-card-tips-and-evergreen-cards.md) | Card tips, evergreen cards, a sibling-only boss | content, cards | |
| [0021](0021-undo-and-delete-entries.md) | Undo and delete the dad's own entries | progress, timeline | 0042 (a first's undo shows in its sheet) |
| [0022](0022-journal-on-every-card.md) | A note and a photo on every card | journal, photos | 0042 (up to five photos) |
| [0023](0023-home-screen-widget.md) | Home-screen widget: weekly quest and latest moment | widget | 0026 (migrations), 0027 (widget strings) |
| [0024](0024-weekly-notification.md) | One gentle weekly notification | notifications, product rules | 0030 (bell button), 0037 (the reminder card waits while a film card shows) |
| [0025](0025-app-icon-and-launch-screen.md) | App icon in Icon Composer, native launch screen | branding | 0033 (also writes the website's images) |
| [0026](0026-versioned-store-and-unavailable-screen.md) | Versioned store with migrations; a calm stop when it can't open | storage, errors | 0034 (widget test before V2), 0042 (V2 and V3 are for photos; `childID` waits for sync) |
| [0027](0027-ui-string-catalog.md) | UI strings in one shared String Catalog | localization | 0030 (reset wording) |
| [0028](0028-screen-queries-and-hero-art-target.md) | One query per screen, one way to record progress, `HeroArt` target | architecture, modules | |
| [0029](0029-hero-look-in-content.md) | A hero class names its look in the content | hero, content | |
| [0030](0030-settings-screen.md) | One Settings screen; "start over" for everyone | settings, privacy | 0036 (start over also forgets the film offers) |
| [0031](0031-website-on-cloudflare-pages.md) | Static website at dadsaga.app on Cloudflare Pages | website, privacy | 0033 (images generated), 0039 (motion in CSS, sticky header), 0040 (own script, tappable family, timeline clip) |
| [0032](0032-contrast-of-tints.md) | Tints readable as text and as fills; the hero keeps its own colours | UI, accessibility, colour | 0033 (its open items) |
| [0033](0033-accessibility-audit-and-secondary-text.md) | Accessibility audit of the main screens, readable secondary text, "D" on the crest | accessibility, testing, colour, hero | 0034 (snapshots at the largest text size, test data for snapshots), 0035 (audit skips, iOS 27.2), 0036 (the audit covers the film sheet), 0037 (a timeline with an entry), 0042 (the photo viewer and a first's second step) |
| [0034](0034-screen-snapshots-pinned-ci-and-store-threads.md) | Screen snapshots, a pinned CI toolchain, the store's work off the main thread | testing, CI, storage, concurrency | 0035 (snapshots get the app's tint), 0036 (film sheet and card snapshots), 0038 (why onboarding's date picker differed by region and by day), 0042 (a first's two steps, the viewer, the timeline with photos) |
| [0035](0035-audit-on-ios-27-shaded-glass.md) | The audit on iOS 27.2: re-measure labels on shaded glass | accessibility, testing | |
| [0036](0036-saga-video.md) | Saga film: drawn frame by frame on the device from the timeline, offered gently, never stored | video, media, product rules, concurrency | 0037 (one offer for the family; what the cards and the sheet show), 0041 (a film with dates gives the age away), 0042 (an entry's further photos, thinned first) |
| [0037](0037-saga-film-drawing-sheet-and-offer.md) | Drawing the saga film in Presentation, its sheet, one offer card for the family | video, architecture, product rules, UI | 0041 (dates on the opening, first and boss cards, behind a switch), 0042 (photos alone include further photos) |
| [0038](0038-date-picker-sized-by-its-date.md) | The date picker is as wide as the date it shows, not as today's | UI, testing, accessibility | |
| [0039](0039-website-motion-in-css.md) | Website motion in CSS only: reveals on scroll, a sticky header, Reduce Motion respected | website, accessibility, motion | 0040 (JavaScript after all; the mock's reveals removed) |
| [0040](0040-website-script-tappable-family-timeline-clip.md) | The website's own script, a family that cheers when tapped, a clip of the real timeline | website, motion, accessibility | |
| [0041](0041-dates-in-the-saga-film.md) | Dates in the saga film, on by default, behind a switch the film sheet remembers | video, product rules, privacy, localization, UI | |
| [0042](0042-several-photos-viewer-and-firsts-in-two-steps.md) | Up to five photos on every entry, a full-screen photo viewer, firsts recorded first and filled in after | photos, storage, moments, video, accessibility, product rules | 0043 (the cover above the fold in the note editor and on a first's page) |
| [0043](0043-panes-above-and-below-the-fold.md) | Panes above and below the fold when iPhone Duo is half-open like a laptop: home, the saga film, the note editor, the quest and boss sheets, a first's page, the wardrobe, the timeline | UI, layout, video, photos | 0045 (home open and upright uses the same two panes) |
| [0045](0045-home-in-two-panes-when-open-upright.md) | Home in the same two panes when iPhone Duo is open and upright; two columns only on its side | UI, layout | |
