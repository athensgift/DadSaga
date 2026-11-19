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
| [0007](0007-clean-architecture.md) | Clean Architecture: Domain, Application, Data, Presentation | architecture | |
| [0008](0008-hero-classes-and-code-drawn-avatar.md) | Hero classes as content, a code-drawn avatar, the profile in SwiftData | hero, avatar, storage | 0010 (class list), 0026 (store fallback), 0028 (avatar target), 0029 (class look) |
| [0009](0009-gitflow.md) | Gitflow: `feature/*` from `develop`, releases on `main` | process, git | |
| [0010](0010-dad-archetype-heroes.md) | Heroes are dad archetypes, not fantasy classes | hero, content | 0029 (class look), 0033 (crest letter) |
| [0011](0011-liquid-glass-and-adaptive-layout.md) | Liquid Glass, system styling, adaptive layout for iPhone Duo | UI, layout | 0030 (developer menu), 0032 (tint values), 0033 (secondary text) |
| [0012](0012-families.md) | Up to four children, XP shared by the dad | family, model | 0023 (migration removed), 0030 (family entry) |
| [0013](0013-child-avatars.md) | Child avatars by age stage | avatar, family | |
| [0014](0014-hero-gear.md) | Gear earned from skills and bosses | gear, avatar | 0018 (wardrobe) |
| [0015](0015-legendary-moments.md) | Legendary moments are progress events with a date and a note | moments, progress | |
| [0016](0016-moment-photos.md) | Moment photos as files on device; moments editable and deletable | moments, photos, privacy | 0021 (delete use case), 0022 (photos on every card) |
| [0017](0017-timeline-and-tabs.md) | A timeline tab derived from progress events | timeline, navigation | |
| [0018](0018-wardrobe.md) | Wardrobe: choose what the hero wears per slot | gear, avatar | |
| [0019](0019-world-map-and-older-worlds.md) | World map, replayable worlds, worlds up to age 6 | worlds, content | |
| [0020](0020-card-tips-and-evergreen-cards.md) | Card tips, evergreen cards, a sibling-only boss | content, cards | |
| [0021](0021-undo-and-delete-entries.md) | Undo and delete the dad's own entries | progress, timeline | |
| [0022](0022-journal-on-every-card.md) | A note and a photo on every card | journal, photos | |
| [0023](0023-home-screen-widget.md) | Home-screen widget: weekly quest and latest moment | widget | 0026 (migrations), 0027 (widget strings) |
| [0024](0024-weekly-notification.md) | One gentle weekly notification | notifications, product rules | 0030 (bell button) |
| [0025](0025-app-icon-and-launch-screen.md) | App icon in Icon Composer, native launch screen | branding | 0033 (also writes the website's images) |
| [0026](0026-versioned-store-and-unavailable-screen.md) | Versioned store with migrations; a calm stop when it can't open | storage, errors | 0034 (widget test before V2) |
| [0027](0027-ui-string-catalog.md) | UI strings in one shared String Catalog | localization | 0030 (reset wording) |
| [0028](0028-screen-queries-and-hero-art-target.md) | One query per screen, one way to record progress, `HeroArt` target | architecture, modules | |
| [0029](0029-hero-look-in-content.md) | A hero class names its look in the content | hero, content | |
| [0030](0030-settings-screen.md) | One Settings screen; "start over" for everyone | settings, privacy | |
| [0031](0031-website-on-cloudflare-pages.md) | Static website at dadsaga.app on Cloudflare Pages | website, privacy | 0033 (images generated) |
| [0032](0032-contrast-of-tints.md) | Tints readable as text and as fills; the hero keeps its own colours | UI, accessibility, colour | 0033 (its open items) |
| [0033](0033-accessibility-audit-and-secondary-text.md) | Accessibility audit of the main screens, readable secondary text, "D" on the crest | accessibility, testing, colour, hero | 0034 (snapshots at the largest text size, test data for snapshots), 0035 (audit skips, iOS 27.2) |
| [0034](0034-screen-snapshots-pinned-ci-and-store-threads.md) | Screen snapshots, a pinned CI toolchain, the store's work off the main thread | testing, CI, storage, concurrency | 0035 (snapshots get the app's tint) |
| [0035](0035-audit-on-ios-27-shaded-glass.md) | The audit on iOS 27.2: re-measure labels on shaded glass | accessibility, testing | |
