# ADR-0043: Panes above and below the fold when iPhone Duo is half-open like a laptop

**Status:** Accepted (2026-11-20). The owner asked for a dedicated layout on three screens when iPhone Duo is half-open
and held upright: home, the saga film and the timeline's note and photos sheet. Changes
ADR-0011 (the fold is read as a reserved region, not through the hinge; its note that CI builds with the iOS 26 SDK
has been out of date since ADR-0034) and ADR-0042 §3 (where the cover sits in the note editor while folded).

## Context
- The Duo's inner display is 669 × 951 pt. Opened like a book (landscape), the fold runs down the middle, and home's
  two equal columns (ADR-0011) already put one on each page. Half-open like a laptop (portrait), the fold runs across
  the middle: the upper half stands, the lower half lies on the table. Home still shows two columns side by side there,
  and the fold cuts through both.
- iOS 27.1 offers three ways to know about the fold:
  - the hinge (`onHingeChange`, `UIHingeInteraction`)
  - reserved regions (`GeometryProxy.reservedRegions(kind: .division)`)
  - `ArrangementView`

  Apple: "Don't use hinge updates for layout. To adapt your layout to the fold, use ArrangementView or ReservedRegion
  instead." The hinge is meant for input, such as animations driven by the angle.
- A division is active only while the device is partially open. Its frame is given in the coordinates of the view that
  reads it, margins included, and only regions that overlap that view are returned. Apple asks for it to be read "in
  the view that positions the content".
- `ArrangementView`'s split style splits flat displays too, and shows only its primary view on an axis it is not allowed
  to split. Its overlay style lays the primary over the secondary on a flat display. It must not sit in a scroll view,
  and it doesn't tell its content which arrangement is in force.
- Sheets without a sizing are form sheets on iOS (`PresentationSizing.automatic` is `.form`). Where the system puts
  them when the fold runs across is not documented. In the iPhone Duo simulator (iOS 27.2, half-open at 90°, portrait)
  the film sheet and the note editor take nearly the whole display, so the fold crosses them, and the keyboard fills
  the lower half.
- `AnyLayout` changes a container's layout "without destroying the state of the subviews".
- The HIG asks to "avoid extreme layout changes as people fold the device".
- The deployment target is iOS 26. CI and the Mac build with Xcode 27.2 (ADR-0034). The package also builds for macOS
  26 to run its tests, and the API is macOS 27.1 there.

## Decision

### 1. The fold is geometry, read where content is placed
- **`HorizontalFold`** (DesignSystem) is where a fold runs across a view: the end of the upper pane and the start of
  the lower one, in the view's own coordinates.
- **One pure rule** finds it, `HorizontalFold.across(size, divisions:, minimumPaneHeight:)`. A fold is the first
  division that runs across the view once clamped to it and spans its width. It must also leave at least the minimum
  above and below it. Otherwise nothing is folded.
- **One reader**, `onHorizontalFoldChange(minimumPaneHeight:_:)`, maps the view's active divisions through the rule. It
  holds the feature's only `#available(iOS 27.1, macOS 27.1, *)`; before iOS 27.1 nothing is ever folded. Each screen
  reads its own container: no value is handed down from the root, since the fold's place in a sheet, under a bar or in
  Split View differs from its place on the display.
- No hinge, no angle, no orientation inference, no hysteresis: the system decides when the fold is active.
- No compile-time guard: CI builds with the iOS 27.2 SDK. From now on the project needs Xcode 27.1 or later.

### 2. One layout, two arrangements, the same views
- **`FoldedStackLayout`** (DesignSystem) places two views: the first above the fold, the second below it, each the full
  width. The fold's band stays empty.
- Each screen switches with `AnyLayout` between its flat layout and this one, around the same views. Nothing on screen
  is rebuilt when the device folds or unfolds (except home in a window narrower than 600 pt, whose single column is
  a different view from the two panes):
  - scroll positions
  - the playing film
  - a picker that is open
  - photos still loading
  - the note field's focus
- The switch animates, and is a cut with Reduce Motion.

### 3. Home
- A fold across home puts the stage above it and today's quests below. The stage is the title with the wardrobe and
  settings buttons, the family, their lines and the level card. Each half scrolls on its own. With two halves scrolling
  separately home has no navigation bar, as in the columns layout (ADR-0011).
- Folded, the upper half is landscape-shaped, so the family stands beside its lines and level card, and the hero keeps
  close to its wide size. At the accessibility text sizes they stack and the half scrolls.
- The tab bar, the undo bar and every control for the quests are on the half that lies on the table. The celebration
  plays on the upright half.
- Otherwise as before: one column below 600 pt, two columns from 600 pt. That includes the inner display flat in
  portrait: the owner prefers its two columns to the folded arrangement there, so folding swaps columns for rows.

### 4. The saga film
- The made film and its controls are two panes in every arrangement:
  - flat: the film on top, at the same size as before, with share, the note and "make another" scrolling under it
  - folded: the film fitted to the upper half and the controls on the lower half
- Folding or unfolding never stops or rebuilds the player. Choosing and making are not split.

### 5. The timeline's note and photos, and a first's own page
- Both use one container, `CoverAndFormPanes`. While folded and while the entry has a photo, its cover is shown whole above the fold. The note, the row of squares,
  "+" and the notes go below it. The cover's square still carries "Make cover" and "Remove", so the upright half shows
  the cover without its "…" button (changes ADR-0042 §3, while folded only).
- With no photo the sheet stays as it is: the upper half never shows an empty frame waiting for one (ADR-0006,
  ADR-0042).
- While the keyboard leaves no room below the fold, the photo gives way and the note fills the space above the
  keyboard, so what the dad writes stays in view. It comes back when the keyboard goes.
- The lower half's minimum grows with the text size; the upper half's does not.

### 6. Sheets that are read, then acted on
- The quest sheet, the boss sheet and the wardrobe use one container, `ReadAndActPanes`. Folded, what the dad reads
  stands above the fold and what he does lies below it, each half scrolling on its own:
  - a quest: its reward, title, description, last note, tip and safety note above; the note, photos and "I did it"
    below
  - a boss: its reward, intro, last note, survival guide and disclaimer above; the note, photos and "We made it
    through" below. A defeated boss has nothing left to do, so its sheet is not split
  - the wardrobe: the hero above, the choices below
- The lower half keeps its place in the view tree, so a fold keeps the note's focus and an open picker. With the
  keyboard up the sheet is one column again.

### 7. What stays as it is
- The book pose (two columns, as in ADR-0011).
- The cover display.
- The lists and forms: the timeline, settings and their pages, onboarding, a first's choice, the world map.
- The timeline list. Apple: scrolling content need not avoid the fold.
- The film's choices.
- The photo viewer.

### 8. Tests
- `FoldLayoutTests` (DesignSystem): the rule and the panes' frames.
- `HomeArrangementTests`, `SagaFilmPlayerLayoutTests` and `CoverAboveFoldTests` (Presentation).
- The reader, the sheets and the keyboard can only be seen in the simulator. Each screen is drawn there once, folded
  and unfolded, with the hinge moved mid-use.
- The snapshots can't draw a fold, so they have no folded images.

## Rejected
- **The hinge** (`onHingeChange`, `UIHingeInteraction`) with a "laptop posture" rule. Apple advises against it for
  layout, and it says nothing about where the fold crosses a sheet or a window in Split View. It would also need an
  orientation inference and hysteresis on an angle whose update rate is system policy.
- **`ArrangementView`.** The split style would change the flat layouts on every iPhone, and the overlay style would need
  new flat designs for all three screens. It can't sit in a scroll view, and it doesn't tell home which arrangement is in
  force.
- **An environment value set at the root:** wrong wherever the fold is not where it is on the display.
- **A reader per screen:** three copies of the same rule.

## Consequences
- On a half-open Duo the screens the dad looks at stand up and the ones he touches lie on the table. On every other
  iPhone, and before iOS 27.1, home and the editor look as before. The film's controls now scroll under the film
  instead of the film scrolling away.
- Folding home from flat swaps its columns for rows: a large change, which the HIG advises against, made at the owner's
  request.
- If a later iOS keeps a sheet off the fold, nothing folds inside it and that sheet looks as before. The code needs
  no change for either case.
- The project needs Xcode 27.1 or later.
- No stored data, content or text changes. Domain, Application, Data and the composition root are untouched.

## Verification status
Drawn once in the iPhone Duo simulator (iOS 27.2), half-open at 90° in portrait: home, the note editor with and
without a photo and with the keyboard up, the made film, a quest sheet and the wardrobe; the film sheet also unfolded
while open. Not checked: the boss sheet and a first's own page (they share the containers of the sheets that were),
a real iPhone Duo, Split View, the accessibility text sizes, VoiceOver, and that a film in mid-play carries on
without a break when the device folds.
