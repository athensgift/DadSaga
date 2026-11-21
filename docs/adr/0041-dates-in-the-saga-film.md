# ADR-0041: Dates in the saga film, behind a switch the sheet remembers

**Status:** Accepted (2026-11-21; proposed 2026-11-20, implemented and merged). The owner asked for dates in the film, on by default, with a switch on the film
sheet to take them out before sharing beyond the family. Changes ADR-0037 §2 ("No dates and no ages on any card", and
what the opening, first and boss cards show), §7 (snapshots) and its consequence that a shared film never shows a date.

## Context
- ADR-0037 §2 left every date out: a date on a first's card, next to the opening's "Year 1", gives the child's age away
  in a film shared beyond the family. ADR-0036 §1 leaves out the child's age at a first.
- The owner accepts that trade. A film watched by the family is clearer with dates. He wants them on by default, and
  one switch that takes them all out before a wider share.
- The storyboard keeps each entry's date (`TimelineEntry.date`) and the moment the film is told as of
  (`SagaStoryboard.asOf`), but not where its period starts: for the whole saga the period starts at `.distantPast`.
  Presenters don't call Domain rules such as `SagaPeriod.interval` (ADR-0028).
- The script holds display strings only (ADR-0036 §5). The cards are drawn by `ImageRenderer` in a pinned environment,
  so anything they formatted themselves would follow that environment, not the dad's.
- Over a photo the words sit on a 0.84 black scrim. The film mixes in linear light, so over a white photo the scrim
  lets 0.16 through: white text reaches 5.0:1, but `DSFilm.secondaryText` (`0xB9B7C6`) only about 2.5:1.
- `Preferences` (ADR-0030 §3) is held by the root and saved whole by Settings (`PreferencesChoice.domain`). A field the
  root doesn't hold would go back to its default with every change of appearance or haptics.

## Decision

### 1. Which cards show a date
| Card | Date | en_US · en_GB · el |
|---|---|---|
| Opening | The months the film covers: from the start of its period to its last day, or to today while it is still going | March 2025 – March 2026 · March 2025 – March 2026 · Μάρτιος 2025 – Μάρτιος 2026 |
| First | The day it happened, as the dad dated it | March 12, 2026 · 12 March 2026 · 12 Μαρτίου 2026 |
| Boss | The day it was beaten | as a first |
| Chapter | None | |
| Quest photos | None: the montage stays wordless | |
| Credits | None | |

- A chapter card is a short title between dated cards: the first or boss after it already places it in time, and a
  second span after the opening's would be more numbers to read for little gain.
- The credits are about the period, not the day the film was made.
- A date is never in the future: a period still going ends today. Nothing says how long ago, how old, or what comes
  next, and the film still shows only what was captured (ADR-0006).

### 2. The span is Domain's
`SagaStoryboard.span: DateInterval`, built in `SagaStoryboard.make`, which already has the period's interval and its
last moment. It runs from the start of the period to the instant before its end, or to now while the period is still
going. For the whole saga it starts at the start of the child's birth day, or at the first entry's day if one is
earlier (a birth date changed later), so the opening never disagrees with a card after it.

### 3. Presentation formats
- `SagaFilmTexts` writes the dates in the film's locale (the app's language and the device's region, ADR-0030 §2),
  with the sheet's calendar and its time zone:
  - a day: `Date.FormatStyle(date: .long, time: .omitted, locale:calendar:timeZone:)`;
  - the span: `Date.IntervalFormatStyle(date: nil, time: nil, locale:calendar:timeZone:).month(.wide).year()` over
    `span.start..<span.end`. It shares a year both ends have ("March – November 2026") and shows one month once.
- Dates are not in the String Catalog: Foundation writes them, in the language of the film's words.
- `SagaFilmViewModel` takes a `calendar` (default `.autoupdatingCurrent`), like `TimelineViewModel`, and passes it to
  `SagaFilmScriptBuilder(locale:calendar:)`. Tests and snapshots pin a Gregorian calendar in UTC.
- `SagaFilmScriptBuilder.script(for:format:reduceMotion:showsDates:)`. Cards gain an optional, already written date:
  `.opening(name:period:dates:family:)`, `.first(emoji:title:date:note:photoID:)`, `.boss(badge:title:date:photoID:)`;
  `nil` when dates are off. `SagaFilmCardView` formats nothing.

### 4. How a date looks
- One style: `DSFilm.caption`, one line that shrinks before it is cut, like every line of a card.
- **Right above the title**, so every card reads "when, what":
  - first over a photo: date, emoji and title, note; boss over a photo: date, title, flame and badge;
  - first as a card of words: emoji, date, title, note; boss: flame, date, title, badge;
  - opening: name, period, then the span under the period.
- **On a card of words** the date is `DSFilm.secondaryText`, already tested at 4.5:1 on the ground.
- **Over a photo** it is `DSFilm.text` (white), like the title: `secondaryText` can't reach 4.5:1 there. The date is
  part of the caption, which lies wholly under the scrim's fade, so ADR-0037's 4.5:1 measurement covers it. No new
  token, and the scrim doesn't change. The caption grows by one line, about 6 % of the frame's shorter side with its gap.

### 5. The switch "Dates in the film"
- On the film sheet, under Format: a `Toggle`, on by default, with one line under it that says what dates give away.
  It shows while the dad chooses, like the format, and clears the notice above the choices like any choice. A film
  already made doesn't change: making it again does ("Make another").
- **Remembered** until the dad changes it, across sheets and launches. A switch that turns itself back on would put
  dates into the next film he makes for a wide share. One that stays off only leaves dates out, in sight on the sheet
  every time, and the dad sees the film before he can share it (ADR-0037 §4).
- **Its own port, not a `Preferences` field.** Application `SagaFilmDatesRepository` (`showsDates() async -> Bool`,
  `setShowsDates(_:) async`) and `SetSagaFilmDatesUseCase`; Data `UserDefaultsSagaFilmDatesRepository`, key
  `sagaFilm.showsDates`, missing reads as on. In `Preferences` it would be reset by Settings, unless the root carried it
  to a sheet that home and the timeline present. ADR-0030 §3 ("a new preference is a new field") still holds for how the
  app looks and feels; this is a film's choice, kept like the film offers' answers (ADR-0037 §5).
- The film's one query reads it (`SagaFilm.showsDates`, ADR-0028). The view model takes it from the first film it
  loads and then keeps its own, so choosing another child or period doesn't reset it. Changes are saved one after
  another, so the newest wins, as in Settings.
- Starting over keeps it, like the preferences (ADR-0030 §8): it is about how this dad shares from this iPhone, not
  about the saga.

  | | el | en |
  |---|---|---|
  | Switch | Ημερομηνίες στην ταινία | Dates in the film |
  | Line | Οι ημερομηνίες δείχνουν και την ηλικία του παιδιού σου. Κλείσε τες για μια ταινία που θα μοιραστείς εκτός οικογένειας. | Dates also tell how old your child is. Turn them off for a film you'll share beyond the family. |

### 6. Tests
- Domain: the span of a finished year, the current year, a world left behind, the last world, and the whole saga with
  an entry before the birth day.
- Application: `SagaFilm.showsDates` is on with nothing stored, and off once stored off.
- Data: the repository reads on when missing and keeps off, under a key of its own.
- Presentation, through the view model as the sheet calls it: with dates on, the opening's span and each first's and
  boss's day, as exact strings in el and en; with dates off, no card has a date. The no-pressure test runs both ways:
  off, as before (no month, no number of two digits); on, only the date fields hold dates, and XP, levels, ages and the
  sibling stay out. The switch is on by default, remembered by the next sheet, kept across a child or period change,
  and clears a notice.
- Renderer: the white-photo readability test draws a dated first.
- Snapshots: the opening, first and boss cards again with dates (Greek vertical, English wide), one first over a photo
  with dates off, and the film sheet with its switch. The making screen and the credits don't change.
- The accessibility audit runs unchanged; its "Film" step covers the switch.

## Consequences
- A film made with dates on gives the child's age away to whoever watches it: the opening's span next to "Year 2"
  gives the birth month, and a first's date the age at that first. The dad chooses, and sees the dates before he can
  share the film. ADR-0036's "the file holds no birth date" stays true of the file's metadata, not of its pictures.
- A film's dates follow the device's region and time zone, as the timeline's do.
- The film card snapshots with a date are recorded again.
- One more key in the app's defaults, kept on start over. No stored schema changes (ADR-0026).
- An entry with several photos (drafted alongside this ADR) keeps one date, on the card with its words.
- Not decided here: dates in the sheet's period menu.
