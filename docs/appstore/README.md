# The App Store listing

What goes into App Store Connect for DadSaga 1.0, kept here so it can be pasted, reviewed and changed in a PR.
The release checklist that points here is `docs/RELEASE.md`.

| File | What it holds |
| --- | --- |
| [`en-US.md`](en-US.md) | English (U.S.): name, subtitle, promotional text, keywords, description, What's New, URLs |
| [`el.md`](el.md) | Greek: the same fields |
| `screenshots/<locale>/<display>/` | The screenshots, `NN-name.jpg` in the order they are uploaded |

## Text limits

App Store Connect counts characters, except keywords, which it counts in bytes (a Greek letter is two bytes in UTF-8,
so the Greek field holds about half as many letters). Words already in the name or subtitle aren't repeated in the
keywords: Apple indexes them anyway.

| Field | Limit | en-US | el |
| --- | --- | --- | --- |
| Name | 30 | 25 | 26 |
| Subtitle | 30 | 30 | 30 |
| Promotional text | 170 | 156 | 157 |
| Keywords | 100 bytes | 93 | 98 |
| Description | 4000 | 2601 | 2997 |
| What's New | 4000 | 52 | 55 |

App Store Connect may not ask for What's New on an app's first version; the text is kept for when it does.

Count again after any change, for example:
`python3 -c "import sys; t=sys.stdin.read().rstrip('\n'); print(len(t), len(t.encode()))" < field.txt`.

## What the text keeps to

- **The rules of the game:** no streaks, no penalties, no deadlines, nothing compared
  ([ADR-0006](../adr/0006-no-pressure-game-design.md)); titles, with the level beside them as home shows it, never XP
  ([ADR-0055](../adr/0055-dad-titles-instead-of-levels.md), [ADR-0059](../adr/0059-level-beside-the-title-and-skills-on-home.md)); every world open, age only sets the current one
  ([ADR-0061](../adr/0061-map-and-settings-tabs-and-every-world-open.md)). Calm wording: no risk, fear or death in
  the text, and the guides called general information, not medical advice.
- **Before the birth is in:** the world before the birth ships in 1.0 (the Harbour of Waiting, its 15 quests and the
  firsts before birth, [ADR-0053](../adr/0053-v1-card-set-before-birth-audiences-and-retired-cards.md)), so the
  text says "from the months before the birth", as the website does. No due date, no countdown.
- **Only what 1.0 does:** no iCloud sync and no co-op ([ADR-0067](../adr/0067-1-0-ships-without-icloud.md)); the saga
  leaves the iPhone only by export and import ([ADR-0057](../adr/0057-saga-copy-export-and-restore.md)), and restoring
  from an iCloud backup is not promised (`docs/ROADMAP.md`, Phase 4).
- **Free:** no in-app purchases ([ADR-0071](../adr/0071-1-0-is-free-with-no-in-app-purchases.md)).
- **The app's Greek words:** the Greek text says «ιστορία», as the app («Ταινία της ιστορίας») and the
  site do, so the description matches the screenshots.
- **The same words as the app and the site:** card, world and title names as the content JSON has them, the site's
  sentences where they fit (`web/index.html`, `web/el/index.html`).

## App Store Connect settings

| Setting | Value |
| --- | --- |
| Price | Free, every territory ([ADR-0071](../adr/0071-1-0-is-free-with-no-in-app-purchases.md)) |
| In-app purchases | None |
| Primary language | English (U.S.); Greek added as a localization |
| Support URL | en `https://dadsaga.app/support/`, el `https://dadsaga.app/el/support/` |
| Privacy Policy URL | en `https://dadsaga.app/privacy/`, el `https://dadsaga.app/el/privacy/` |
| Marketing URL | en `https://dadsaga.app/`, el `https://dadsaga.app/el/` |
| Copyright | `2026 FAFOUTIS BROTHERS E.E.` |
| App Privacy | **Data Not Collected**. It must match `web/privacy`, `web/el/privacy` and the privacy manifests (ADR-0051) |
| Age rating | "Medical or Treatment Information": **Infrequent**. "Health or Wellness Topics": **Yes** (self-care advice: the Resilience skill, sleep, feeding). Read the live table in App Store Connect for the tier these give. Everything else None or No: no violence, no mature themes, no gambling or contests, no unrestricted web access, no user-generated content shared with others (notes and photos stay on the iPhone), no messaging, no ads. Not "Made for Kids": the app is for parents |
| Category | The owner's choice; Lifestyle fits a parenting app best |

## Screenshots

Checked on 2026-11-24 against Apple's
[Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications):

- **Required for an iPhone app:** at least one screenshot for "iPhone with Dynamic Island (medium display)",
  1206 × 2622 or 1179 × 2556 portrait (iPhone 17 and the like). Up to 10 per size, `.jpeg`, `.jpg` or `.png`,
  **no alpha channel**. Apple scales them down for smaller iPhones when the screens look the same; a set for the large display
  (1320 × 2868, Pro Max and Air) is optional, and none is made yet.
- **iPhone Duo has its own two sizes:** the outer display 1398 × 2034 and the inner display 2007 × 2853 (portrait).
  They are optional today. Apple's note: from April 2027, screenshots will be required for any app using the
  iOS 27.1 SDK or later, and a product page with iPhone Duo screenshots shows a badge that the app is made for iPhone
  Duo. Apple lists no fallback for them: no iPhone set covers the Duo. DadSaga builds with the iOS 27.2 SDK, so any build
  submitted from April 2027 needs them, and it lays out the Duo's displays on purpose (ADR-0043, ADR-0066): the listing
  carries both Duo sets from 1.0.
- **iPad:** not needed. The app is iPhone only (`TARGETED_DEVICE_FAMILY: "1"` in `project.yml`).

| Folder | Display | Simulator | Size |
| --- | --- | --- | --- |
| `iphone-medium-1206x2622` | iPhone with Dynamic Island (medium display), required | iPhone 17 | 1206 × 2622 |
| `duo-outer-1398x2034` | iPhone Duo, outer display (closed) | iPhone Duo, `--display=1` | 1398 × 2034 |
| `duo-inner-2007x2853` | iPhone Duo, inner display (open flat) | iPhone Duo, `--display=3` | 2007 × 2853 |

### How they were made

The demo saga in each language (`docs/demo/demo-{en,el}.dadsaga`, [ADR-0070](../adr/0070-website-demo-video-and-real-screens.md)),
imported as `docs/demo/README.md` describes, in light appearance with the status bar at 9:41, full battery and bars.
Each screen is `xcrun simctl io <UDID> screenshot --type=png` (on the Duo with `--display=1` or `--display=3`), then
`sips -s format jpeg -s formatOptions 95` to drop the alpha channel the simulator adds. The ages and worlds follow the
day they were taken (2026-11-24): Lena is four months old, in the Swamp of No Sleep.

### The shots

The same screens in both languages, in upload order. The iPhone set has eight; each Duo display has six (no quest
recorded on camera, so the saga stays as imported).

| iPhone | Duo | Screen |
| --- | --- | --- |
| `01-home` | `01-home` | Adventure: Super Dad, Lena and Alex, "Level 3 · Dad with a few tricks", the Swamp of No Sleep and its quests |
| `02-quest` | | The "Bath master" sheet with its tip, before it is recorded |
| `03-title` | | "Bath master" recorded: the calm title card, "You became Steady hands", the changing bag |
| `04-boss` | `02-boss` | Alex's boss, The Velcro Phase, and the start of its survival guide |
| `05-first` | `03-first` | A legendary moment with its photo and note (Lena's first smile or Alex's first steps) |
| `06-timeline` | `04-timeline` | The Timeline for everyone, month by month |
| `07-film` | `05-film` | The Saga film sheet: Lena, the whole saga, vertical |
| `08-map` | `06-map` | The world map, Lena in the Swamp of No Sleep |

They go out of date as `docs/demo/README.md` says the demo video does: when a screen they show changes, and as the demo
saga ages (Lena leaves the Swamp of No Sleep at 9 months, on 12 April 2027). Taking them again follows the steps above.
