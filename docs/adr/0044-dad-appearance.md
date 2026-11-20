# ADR-0044: The dad's own look, the wardrobe in Settings, and the world map in home's toolbar

**Status:** Accepted (2026-11-20). The owner asked for a beard (none, short, full), glasses and a few more choices so
the hero can look like the dad, and decided that the wardrobe moves into Settings and the world map gets a toolbar
button; designed by the architect. Changes ADR-0008 (the avatar draws the dad's own features, not one face for every
dad), ADR-0018 (the wardrobe is a page in Settings, not a sheet from home), ADR-0019 (the map opens from home's
toolbar, not from the world's header) and ADR-0030 §1 and §5 (a wardrobe row; "Your hero" holds the dad's look and
saves at once; home's toolbar).

## Context
- Every dad is drawn with the same face: short hair, a full beard with a moustache, no glasses (`HeroHead`). Hair,
  beard and brows take their colour from the skin tone (`AvatarSkin.hair`): brown for the three lighter tones,
  near-black for the two deeper ones. Smart Dad's round glasses and Cool Dad's shades belong to their archetype
  (`HeroHeadgear`). A dad with glasses, a shaved head or no beard cannot make the hero look like him.
- The skin tone is the only feature he chooses. It is on the profile row (`ProfileRecord.dadSkinTone`), changed on
  "Your hero" through `UpdateHeroUseCase` and read through `GetHeroChoiceUseCase` (ADR-0030 §5). That page saves with
  a ✓ and pops back; leaving it with the back button drops what was changed, and nothing says so. The wardrobe, in the
  same section of Settings, stores each choice at once (ADR-0018).
- The dad is drawn by `HeroAvatar` on home (`FamilyStage`), in the wardrobe's preview, in the hero picker (onboarding
  and "Your hero") and on the film's opening card (`FamilyStage` again, ADR-0037), and by `Tools/LaunchLogo` for the
  launch screen and the website (Super Dad, medium-light). The widget draws no avatar (ADR-0028 §5).
- The store is at version 3 (ADR-0042). Every change to a stored property is a new version, migrated and tested from
  the version before, read-write by the app and read-only by the widget (ADR-0026 §2). Core Data's lightweight
  migration infers a new attribute, and an optional one is nil in the rows already there. Developers report that the
  Swift default of a new non-optional property does not reliably reach existing rows, and that an enum stored in a
  `@Model` must be `Codable`.
- Settings already has "Appearance" («Εμφάνιση») for light and dark (ADR-0030 §3), so the word is taken on screen; in
  code, `Appearance` is that preference.
- Home's toolbar has the wardrobe and Settings (ADR-0030 §1). The world map opens from the world's header, in home's
  scrolling content (ADR-0019), away from the screen's other actions.
- ADR-0006: nothing is earned, locked or lost, and nothing invites comparison or guilt.

## Decision

### 1. Four choices, all free

| Part | Options, in the content's order | Until the dad chooses |
|---|---|---|
| Hair | short, curly, long, shaved | short |
| Hair colour | black, brown, blond, red, grey | brown for the light, medium-light and medium skin tones; black for medium-dark and dark |
| Beard | none, short, full | full |
| Glasses | none, round | none |

- The last column is exactly how the avatar draws every dad today, so no dad looks different after the update, and
  neither do the launch screen and the website.
- The skin tone stays a field of its own: the children use the same scale (ADR-0013), and its names stay in the String
  Catalog with the child editor's.
- No body shape, weight, height or age (a belly, wrinkles): they invite comparison and self-judgement (ADR-0006).
  Strong Dad's build belongs to his archetype, as before.
- Free and unlimited, as a hero class is (ADR-0008, ADR-0030 §5): never earned or locked, no XP, no celebration,
  nothing that calls a look new. Changing it never touches progress or the wardrobe.

### 2. One place: "Your hero"
- The look goes on "Your hero" (Settings › Hero & family), which already holds the skin tone, not on a page of its
  own: everything about how the dad himself looks is in one place. The wardrobe keeps what is earned (ADR-0018); free
  choices among locked items would look gated.
- The page, top to bottom: the chosen hero, large, drawn live with the look and without gear (like the wardrobe's
  preview); then the hero picker as it is today, its skin tone row now followed by hair, hair colour, beard and glasses
  under a "Your look" heading, each a menu picker showing the chosen option's name; then the hero grid, whose cards
  draw the dad's look too.
- **It saves at once,** like the wardrobe and the preferences beside it: no ✓ and no pop back. A change shows at once
  and is stored; saves run one after another and each stores the whole choice (hero, skin tone, look), so the store
  ends with the newest. If a save fails, the page says "Couldn't save. Please try again." and goes back to what is
  stored, unless a newer change is already on its way. This replaces ADR-0030 §5's ✓ for this page; "My family"
  keeps its Save, because names and dates are typed.
- **Onboarding stays as it is:** the skin tone and the hero grid. Its cards draw the standard look for the tone chosen,
  which is the look the profile is created with. Onboarding does not mention the look, and nothing asks about it later.

  | | el | en |
  |---|---|---|
  | Heading | Το στυλ σου | Your look |
  | Rows | Μαλλιά · Χρώμα μαλλιών · Γένια · Γυαλιά | Hair · Hair colour · Beard · Glasses |

### 3. The option names are content
- `appearance.json` in `Data/Resources` lists each option once, in the order the menus show them:
  `{ "part": "beard", "id": "full", "title": { "el": "Γεμάτα", "en": "Full" } }`. `id` is the Domain case's raw value,
  unique within its part only ("short" is a hair and a beard), so it stays out of the catalog-wide id check.
- At load the mapper rejects an unknown part, and `ContentValidator` requires each part to list every Domain option
  exactly once: an unknown id, a missing one or a repeated one fails, so an option can neither appear without its
  drawing nor drop out of a menu ([ADR-0005](0005-content-as-data.md)).
- The standard look is Domain code, not content: changing it would change how existing dads look.

  | Part | el | en |
  |---|---|---|
  | Hair | Κοντά · Σγουρά · Μακριά · Ξυρισμένα | Short · Curly · Long · Shaved |
  | Hair colour | Μαύρα · Καστανά · Ξανθά · Κόκκινα · Γκρίζα | Black · Brown · Blond · Red · Grey |
  | Beard | Καθόλου · Κοντά · Γεμάτα | None · Short · Full |
  | Glasses | Καθόλου · Στρογγυλά | None · Round |

  The Greek adjectives agree with «μαλλιά», «γένια» and «γυαλιά» (neuter plural).

### 4. How each option is drawn
`HeroArt` gains `HeroFeatures` (hair, hair colour, beard, glasses; `.standard` is today's face). `HeroAvatar`
takes it as `features:` and puts it in the environment, as it does the equipment. Positions are in `HeroFigure`'s
design canvas.

| Option | Drawing |
|---|---|
| Hair: short | Today's dome and sideburns. |
| Hair: curly | Overlapping circles along the top of the head, and small curls for sideburns. |
| Hair: long | Today's dome, and hair behind the head down to the jaw, showing on both sides of the face and under every hat. |
| Hair: shaved | No dome, sideburns or quiff; a faint highlight on the scalp. |
| Hair colour | Hair, Super Dad's quiff, brows and beard. Black and brown are today's two colours. Blond, red and grey are new art colours, fixed like the skin tones and checked against all five. |
| Beard: full | Today's beard and moustache. |
| Beard: short | The same shape cut to a band along the jaw, with a thinner moustache. |
| Beard: none | No beard or moustache; the smile gets a thin ink outline so it reads on skin. |
| Glasses: round | Smart Dad's frames, moved from his headgear to the face and drawn over the eyes. |

- **Where the archetype's own things meet the dad's, the archetype wins:** Smart Dad always wears his round glasses
  (they are part of him, like the chef's hat), and Cool Dad's shades cover any glasses. Hats, the headband and the
  hard hat still sit on top of the hair. One function on `HeroAvatar.Style` decides which glasses are worn; the grid
  shows the choice on the other four heroes.
- The children keep the hair colour of their skin tone. `AvatarSkin.hair` reads black and brown from
  `HeroFeatures.HairColor`, so each colour is defined once.

### 5. One field on the profile, one port extended
- **Domain:** `DadAppearance` (`hair`, `hairColor`, `beard`, `glasses`: nested enums with `String` raw values, and
  `Part`), with `DadAppearance.standard(for: SkinTone)`; `DadAppearanceOption` (`part`, `id`, `title`).
  `PlayerProfile.dadAppearance`: a profile made with only a skin tone has the standard look for it.
  `ContentCatalog.appearanceOptions`.
- **Application:** no new port. `UpdateHeroUseCase.execute(heroClassID:skinTone:appearance:on:)` replaces
  `execute(heroClassID:skinTone:on:)`, and `HeroChoice` adds `appearance` and `appearanceOptions`. Home, the wardrobe
  and the film already read the profile through their one query each (ADR-0028).
- **Presentation:** `DadAppearanceChoice`, a display value mapped to `HeroFeatures` in `HeroLook+Avatar.swift`:
  the same split as skin tone and gear (ADR-0029). The hero page's presenter keeps the Domain value and changes it by
  the content's option id; its rows are display models carrying the content's names.

### 6. Stored on the profile row: version 4
- `SchemaV4` (4.0.0) is version 3 with four optional `String` columns on `ProfileRecord`: `hairStyle`, `hairColor`,
  `beard` and `glasses`, holding raw values. It is `CurrentSchema`, and V3 → V4 is `.lightweight`. Rows from version
  3 have nil there; nil or an unknown value reads as that part of the standard look for the stored skin tone. Every
  save writes all four.
- **Optional, not non-optional with a default:** that a default reaches existing rows is not documented, and nil has
  to read as the standard look anyway. **Strings, not stored enums:** an unknown value never breaks a read.
- **Not a record of its own, and not `UserDefaults`:** the look is the dad's, like his skin tone, which is already on
  this row. A second record would need its own single-row rule; defaults would sit outside the store, outside a future
  sync (ADR-0026 §6) and outside the erase's one write.
- **Starting over** erases the look with the profile row, in the same save (ADR-0030 §8). `SwiftDataSagaEraser` does
  not change; a test checks that the profile made after starting over has the standard look.
- **Tests:** a new fixture, `Tests/DataTests/Fixtures/StoreV3`, written by the version 3 build before the schema
  changes and never regenerated: a dad with a medium-dark tone, two children, entries with photos and a wardrobe
  choice. The app opens a copy read-write and finds everything as it was, and the dad with the standard look for his
  tone (black hair). The widget opens a copy read-only at version 4, throws, and leaves the database and its
  write-ahead log byte for byte as they were; once the app has migrated, it reads it. The version 1 and pre-version 1
  fixtures still open.
- An older build cannot open a version 4 store; it shows the calm "couldn't open" screen (ADR-0026).

### 7. Everywhere the dad is drawn
Home's family, the wardrobe's preview, the hero page's preview and grid, onboarding's grid (the standard look for the
chosen tone) and the film's opening card all draw the dad's look. The film draws him as he looks now, as it already
uses his current hero and skin tone; no history is kept. Onboarding's welcome picture comes before the dad has said
who he is, and stays standard. The launch screen and the website draw the standard look: regenerating them changes no
image.

### 8. Home's toolbar: the world map and Settings
- **The wardrobe moves into Settings,** as a "Wardrobe" row in Hero & family, between "Your hero" and "My family". The
  toolbar button on home is deleted. The wardrobe becomes a pushed page like Settings' others (ADR-0030 §1), without a
  `NavigationStack` or close button of its own. Home reloads when Settings closes, so the hero wears the new choice.
- **The world map gets a toolbar button beside Settings** ("World map", the map symbol), and the same icon button
  beside Settings in the wide layout's header.
- **The world's header no longer opens the map.** One way in, which looks like a button and is announced as one; the
  world's name is a heading again. "Back to the current world" stays under it.
- Home still has two buttons.

### 9. Where the code goes

| Layer | Adds | Changes or removes |
|---|---|---|
| Domain | `DadAppearance` (with `Part`), `DadAppearanceOption` | `PlayerProfile.dadAppearance`, `ContentCatalog.appearanceOptions` |
| Application | | `UpdateHeroUseCase` takes the look; `HeroChoice` carries it and its options |
| Data | `appearance.json`, `AppearanceOptionDTO`, `SchemaV4`, the `StoreV3` fixture | the migration plan (V3 → V4), the profile record's mapping, `ContentValidator`, `ContentDataError` |
| HeroArt | `HeroFeatures` and its drawing | `HeroHead`, `HeroHeadgear` (Smart Dad's frames move to the face), `AvatarSkin.hair` |
| Presentation | `DadAppearanceChoice`; `AppearanceSection`, `AppearanceRow`, `AppearanceOptionModel`; the hero page's preview | `HomeContent`, `WardrobeContent`, `SagaFilmFamily`, `FamilyStage`, `HeroPicker`; `HeroSettingsViewModel` saves at once (its ✓, `canSave` and `onSaved` go); `SettingsPages.MakeHero`; the wardrobe's toolbar button and the header's map tap go |
| App | | `makeHeroSettingsViewModel()` without `onSaved` |
| UITests | | the audit reaches the wardrobe through Settings |

### Deferred
- More hair styles, colours, beards or frames: a content entry, a Domain case and a drawing, with no schema change.
- Showing the current hero or look on the Settings row (ADR-0030's deferred item).
- A film drawing the dad as he looked then: it draws him as he looks now.

## Verification status
Not yet checked on a device. Screen snapshots and the accessibility audit are paused (owner, 2026-11-20) and run once
this is close to final. To check:
- every option on all six heroes, on all five skin tones, in light and dark, at the picker's size and at home's
  smallest (four children on the iPhone Duo cover display);
- the film's opening card with a look other than the standard;
- installing over a version 3 build: the dad looks exactly as before; the widget before the app opens, and after;
- the hero page saving at once, and its message when the store can't be written;
- VoiceOver on each row ("Beard, Full"); Greek at the largest text sizes;
- the launch images and the website's images unchanged after regenerating them (`Tools/LaunchLogo`).

When the snapshots run again: home and Settings are recorded again (the toolbar and the wardrobe row), and "Your hero"
gets images in the three looks. The audit reaches the wardrobe through Settings and covers "Your hero".

## Consequences
- The hero can look like the dad, and every dad looks as before until he changes something.
- One stored version more, and three more small binary files for the `StoreV3` fixture.
- A new option is content, a Domain case and a drawing; no stored change.
- "Your hero" behaves like the rest of Settings. A dad who taps another hero has switched; tapping back switches back.
- The glasses choice changes nothing on Smart Dad (always in his glasses) or Cool Dad (always in shades); the grid
  shows it on the other four.
- The wardrobe is one tap further from home. The map is in reach wherever home is scrolled to.
