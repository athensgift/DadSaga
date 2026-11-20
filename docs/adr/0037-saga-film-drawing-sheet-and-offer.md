# ADR-0037: Drawing the saga film, its sheet, and one offer card for the family

**Status:** Proposed (2026-11-20). Decided by the architect while the owner was away, to let parts 5 and 6 of Phase 3½
go ahead; the owner accepts or changes it when reviewing them. Fills in ADR-0036 §4–§7 and §9–§10, and changes
ADR-0024 §3 (the reminder card waits while a film card shows), ADR-0033 (the audit's timeline has an entry) and ADR-0036
§7 (one offer for the whole family).

## Context
- ADR-0036 says Presentation draws the film behind a `SagaFilmRendering` protocol, and that view models import neither
  SwiftUI nor AVFoundation. It does not say which target links `FilmKit`. The cards need `HeroArt` and Presentation's
  internal display-to-art mappings (`HeroLook.avatarStyle`, `SkinToneChoice.avatarSkin`, `CompanionStage.avatarStage`,
  `HeroGearLook.heroItem`, `avatarTraits`).
- `SagaOccasions.latest(for:)` picks one occasion per child. Home has one place for an offer, and a family has up to
  four children. Home already has one calm offer card, the weekly reminder (ADR-0024 §3).
- ADR-0036 leaves out the child's age at a first. A date on a first's card, next to the opening's "Year 1", gives the
  age away.
- A film is played from a temporary file and shared through the system share sheet, which is presented over the film
  sheet. Deleting the file while the share sheet is still up would break the share.
- `GetPhotoUseCase` returns `nil` for a photo it can't read (rare: a damaged file).

## Decision

### 1. Where the drawing lives
- **Presentation depends on `FilmKit`.** `SagaFilmRendering` (protocol) and `SagaFilmRenderer` (its implementation)
  live in `Presentation/SagaFilm`, the card views next to them. `FilmKit` is a leaf that knows no game, and only the app
  links Presentation (never the widget), so dependencies still point inward.
- Rejected: a separate rendering target. It would depend on Presentation for the script, and Presentation's
  display-to-art mappings would have to become public or be copied.
- Files whose name contains `ViewModel` import none of SwiftUI, UIKit, AVFoundation, AVKit, FilmKit, HeroArt or
  DesignSystem. A SwiftLint custom rule checks this (ADR-0007).

### 2. What the cards show
- Every card is a complete, always-dark picture with its own background (`DSFilm` tokens: fixed colours, never adaptive;
  type sized from the frame's shorter side; margins kept clear of the overlays that social apps put at the top and
  bottom of a vertical video).
- **No dates and no ages on any card.** No "to be continued" or anything about what may come next.
- Opening: the child's name, the period ("Year 2", the world's title, "The whole saga"), and the hero next to the child,
  drawn as on home (`FamilyStage`) as they were at the end of the period.
- Chapter: "Chapter 2", the world's title and tagline.
- First: emoji, title and the dad's note (at most two lines), over its photo if it has one.
- Boss: badge and title, over its photo if it has one.
- Quest photos: the photo alone, no words (a montage).
- Credits: "Starring" the child, "The hero" the class's title, "Together" with quests and bosses done in the period (a
  zero count is left out), "Music" with the title and artist ("Public domain (CC0)" for a CC0 track), and "Made with
  DadSaga".
- **Every photo is shown whole** (`FilmFit.fitOverBlur`) in both formats, so a crop never cuts a face.
- A photo that can't be read leaves its scene's words over the dark background; the film is still made.

### 3. How it moves
- Every scene fades in from the one before (12 frames; 9 in the quest montage); only the first starts with a cut.
- Photos glide (Ken Burns), alternating in and out between zoom 1.0 and 1.12, towards the upper middle where faces
  usually are. It's the same on every run, so tests and snapshots repeat.
- **Reduce Motion**, read when the dad makes the film, keeps the photos still. Scenes fade either way, and the cards
  never move.

### 4. The film sheet
- The dad chooses a child (only with siblings), a period (`SagaFilm.availablePeriods`) and a format (vertical by
  default, or wide), then makes the film. A period with nothing in it has no make button. A calm line explains
  instead, and never says what the dad didn't do.
- **While making:** a progress bar and Cancel. Swiping the sheet down is disabled, and the screen stays awake
  (`UIApplication.isIdleTimerDisabled`, reset afterwards). Close cancels.
- **Leaving the app** (`scenePhase == .background`; `.inactive` does not count) cancels. The sheet returns to the
  choices, says the film stopped when the dad left DadSaga, and offers "Make it again".
- **Made:** the film plays at once in `VideoPlayer`, with the default audio session, so the silent switch is respected.
  Sharing is offered only on this screen, next to the playing film, with no "watch to the end" gate. The shared item is
  a `Transferable` with `FileRepresentation(exportedContentType: .mpeg4Movie)`, so Photos' "Save Video", Messages and
  AirDrop are offered and each receives the system's own copy. Another format, or another period, means making the
  film again.
- **Files:** `tmp/SagaFilms/<uuid>/<child's name> – DadSaga.mp4`. The whole `SagaFilms` folder is deleted before each
  film, when the sheet is dismissed, and at launch, which catches what a crash left behind. The sheet deletes on
  dismissal (`onDismiss`), never on `onDisappear`, so the share sheet over it can't delete the film it is sharing.
- A link from outside the app (ADR-0023) closes the film sheet like home's other sheets.

### 5. One offer card, for the whole family
- `SagaOccasions.latest(forFamily:…)` takes the newest occasion of any child. On the same day, children go in family
  order, and a world's end comes before a birthday. Once the dad answers it, no older occasion of any child takes its
  place. A sibling's occasion on the same day (twins) may.
- Home's one query computes it (`HomeOverview.sagaOffer`, ADR-0028). Answers live in the app's defaults, one key per
  occasion (`sagaOffer.answered.<occasion id>`), so two answers never overwrite each other. Starting over removes them
  (ADR-0036 §7).
- **Home shows at most one offer card.** While the film card shows, the weekly reminder card waits, and comes back on a
  later load once the film card is gone (changes ADR-0024 §3).
- Answering is stored at the tap. "Make the film" opens the sheet for that child and period; "Not now" closes the card
  for good.

  | | el | en |
  |---|---|---|
  | Title | Μια μικρή ταινία; | A short film? |
  | Line | «Όνομα» · «περίοδος» | «Name» · «period» |
  | Message | Οι φωτογραφίες, οι πρώτες φορές και οι σημειώσεις σου από αυτή, σε μια ταινία με μουσική. Φτιάχνεται σε αυτό το iPhone. | Your photos, firsts and notes from it, as a film with music. Made on this iPhone. |
  | Buttons | Φτιάξε την ταινία · Όχι τώρα | Make the film · Not now |

### 6. The timeline
A "Make a film" button in the timeline's toolbar, shown whenever the timeline has an entry. It opens the sheet for the
child the timeline is filtered to, or for the first child.

### 7. Tests
- The renderer's tests encode real films at a sixth of the size, through an internal initialiser. One test at full size
  checks 1080 × 1920 and 1920 × 1080.
- Snapshots: the cards as `SagaFilmRenderer.cardImage` draws them (Greek vertical, English wide), the sheet while
  choosing and while making, and home with the offer. The finished film is not snapshotted: `VideoPlayer` is composited
  by Core Animation.
- The accessibility audit completes the quest it opens, so it audits a timeline with an entry instead of the empty one,
  then the film sheet before and after making a film.

## Consequences
- Presentation builds `FilmKit` too. The app was already its only user.
- A shared film never shows a date or an age. The dad sees and hears the film playing before he can share it.
- A dad with several children sees at most one film card, for the newest occasion. The other films are a tap away on
  the timeline.
- The reminder card can show up a little later than before, never earlier.
- No stored schema changes: `SchemaV1` and the store fixture are untouched (ADR-0026).
- If the audit flags `VideoPlayer`'s own system controls, only issues on elements inside the player's frame are
  exempted, and the test says why. Everything else still fails.
