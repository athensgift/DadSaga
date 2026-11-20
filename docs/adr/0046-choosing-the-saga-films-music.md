# ADR-0046: Choosing the saga film's music: five original tracks, heard before choosing, the last choice remembered

**Status:** Proposed (2026-11-20). The owner asked for the dad to choose his film's music; four more
original tracks are made with `Tools/SagaMusic`. Drafted by the architect. Changes ADR-0036 §8 (five bundled tracks, each with a
Greek and an English title and a mood line), ADR-0037 §2 and §4 (the credits name the track in the film's language; the
sheet gains a music choice and can play a track before the film is made), ADR-0041 §5 (its port keeps the music choice
too) and ADR-0007 (a presenter may also hold a protocol that plays sound).

## Context
- One track is bundled (`saga-theme`, ADR-0036 §8). `DefaultGetSagaFilmUseCase` takes `fetchSoundtracks().first` and
  throws `noSoundtrack` when there is none: the app is broken, not the saga.
- `soundtracks.json` and the audio live in the `SagaMusic` target, which only the app links; `BundledSoundtrackRepository`
  (Data) reads them from the bundle the app passes in. A track's `title` is one string, credited the same in Greek and
  English. ADR-0005 asks for every text of content as `{ "el": …, "en": … }`; ADR-0027 §5 keeps content out of the String
  Catalog, which the widget links too.
- The four new tracks are original, by `DadSaga`, each at least 95 seconds: playful and bouncy, a 3/4 music-box lullaby,
  heroic with drums, warm acoustic fingerpicking. With five, a name alone doesn't say how a track sounds.
- A film starts its music at the beginning and trims it to its own length (ADR-0036 §3). A short film plays only the
  opening of a track.
- The sheet already remembers one choice, the dates switch, through `SagaFilmDatesRepository` (ADR-0041 §5): the view
  model takes it from the first film it loads, keeps its own after that, and saves changes one after another.
- View models import no AVFoundation (ADR-0037 §1, SwiftLint `view_model_imports`). The made film plays in `VideoPlayer`
  with the default audio session (ADR-0037 §4). Apple: the default category, `soloAmbient`, is "silenced by screen
  locking and by the Silent switch", and activating it interrupts other apps' audio that can't mix.
- `AVAudioPlayer` plays a local file (iOS 2.2+, `Sendable` in the current SDK) and fades with
  `setVolume(_:fadeDuration:)` (iOS 10+). In a `Menu`, a `Button` or a `Toggle` whose label is two `Text`s shows the
  second as a subtitle, and a `Toggle` shows a checkmark; Apple doesn't document a subtitle for a `Picker`'s options.
  `AccessibilityTraits.startsMediaSession` (iOS 13+) silences VoiceOver when a control starts sound.
- The film's choices are not split by the fold on iPhone Duo (ADR-0043 §4, §8).
- The sheet may be opened next to a sleeping child.

## Decision

### 1. Five tracks, as content
| id (file `<id>.m4a`) | Sound | en title · mood | el title · mood |
|---|---|---|---|
| `saga-theme` | gentle, D major, 80 BPM | Saga Theme · Gentle and hopeful | Το θέμα της ιστορίας · Απαλό και αισιόδοξο |
| `candles-and-confetti` | playful, bouncy | Candles and Confetti · Playful and bouncy, for birthdays | Κεράκια και κομφετί · Παιχνιδιάρικο και ζωηρό, για γενέθλια |
| `music-box-lullaby` | tender lullaby in 3/4, music box | Music Box Lullaby · Tender and slow, for quiet moments | Νανούρισμα για μουσικό κουτί · Τρυφερό και αργό, για ήσυχες στιγμές |
| `great-adventure` | heroic, drums, brass-like pad | The Great Adventure · Bold and heroic, with drums | Η μεγάλη περιπέτεια · Τολμηρό και ηρωικό, με τύμπανα |
| `like-yesterday` | warm, nostalgic, fingerpicked guitar | Like Yesterday · Warm and nostalgic, on guitar | Σαν χθες · Ζεστό και νοσταλγικό, με κιθάρα |

- `soundtracks.json` gives each track a bilingual `title` and `mood`, as ADR-0005 asks of all content. The artist stays
  one name. A CC0 track keeps its own title, the same in both languages.

  ```json
  {
    "id": "music-box-lullaby",
    "file": "music-box-lullaby.m4a",
    "title": { "el": "Νανούρισμα για μουσικό κουτί", "en": "Music Box Lullaby" },
    "mood": { "el": "Τρυφερό και αργό, για ήσυχες στιγμές", "en": "Tender and slow, for quiet moments" },
    "artist": "DadSaga",
    "licence": "original",
    "source": "Tools/SagaMusic"
  }
  ```
- The order in the file is the order on the sheet, and the first track is the default.
- An id is stored once the dad chooses its track (§4), so it never changes after a release. A track leaves by having
  its entry deleted; its id is never given to another.
- Checked at load: unique ids, and no title, mood or artist empty in either language (`ContentDataError.emptyText`,
  which replaces `emptyCredit`). How many tracks there are is not a load rule: a test checks the five, and that each
  lasts at least 95 seconds.
- Every track is there from the first film. Music is never earned, unlocked or given as a reward (ADR-0006).

### 2. Where the dad chooses
- On the film sheet's choices, under Format and above the dates switch: "Music", then one row. The row is a menu that
  shows the chosen track's title with its mood under it, and a round play button beside it.
- The menu lists the tracks in order, each with its mood as a subtitle and a checkmark on the chosen one. The items are
  `Toggle`s labelled with two `Text`s, since Apple documents both the checkmark and the subtitle for them. Turning one
  on chooses it; turning the chosen one off does nothing.
- One row, like the period's menu: the sheet grows by one row, not by five, and "Make the film" stays where it was.
- Choosing a track clears the notice above the choices, like any choice. Listening doesn't.
- iPhone Duo: the choices scroll across the fold as before (ADR-0043 §8). Nothing is split.
- At the accessibility text sizes the title and mood wrap; the button keeps at least 44 × 44 pt.

### 3. Hearing a track before choosing it
- The button plays the chosen track from its start, which is how a film opens, for 20 seconds, the last 1.5 fading out.
  Tapped again, it stops. Choosing another track while one plays plays the new one from its start.
- It stops when the dad stops it, when its 20 seconds are over, when he makes the film, when the sheet closes, when the
  app goes to the background, and when a film can't be loaded. Only one plays at a time.
- **Nothing plays until the dad taps the button:** not when the sheet opens, and not when he chooses a track while
  nothing plays.
- The audio session is left as it is, the default, like the film's player: the Ring/Silent switch silences the preview,
  and it pauses another app's audio, which doesn't resume by itself, as after watching the film.
- **Presentation plays it.** `SagaMusicPreviewing` (a `@MainActor` protocol: `play(_ url: URL, seconds: Double) async`,
  which returns once it has played, or as soon as its task is cancelled, with the sound stopped either way).
  `SagaMusicPreviewer` implements it with `AVAudioPlayer`. The view model holds the protocol, starts a play in a task
  and cancels the task to stop it, as it does with `SagaFilmRendering`.
- VoiceOver: the button is "Listen to the music" or "Stop the music", and has `.startsMediaSession` while it would start
  one. The menu is "Music", with the chosen title and its mood as its value.
- Reduce Motion changes nothing: nothing moves, and the play and stop symbols swap without animation.

### 4. The last choice is remembered
- The next sheet opens with the track last chosen, across launches, until the dad chooses another. A dad who likes one
  track shouldn't have to choose it again for every film.
- **One port for what the film sheet remembers.** `SagaFilmDatesRepository` becomes `SagaFilmChoicesRepository`, with
  `soundtrackID() async -> String?` and `setSoundtrackID(_:) async` next to the dates. `UserDefaultsSagaFilmChoicesRepository`
  keeps `sagaFilm.showsDates` (unchanged, so a stored switch carries over) and `sagaFilm.soundtrackID`.
  `SetSagaFilmMusicUseCase` saves a choice.
- The film's one query reads it (ADR-0028): `SagaFilm.soundtracks`, every bundled track in order, and
  `SagaFilm.soundtrack`, the one remembered, or the first when none was chosen or it is no longer bundled.
  `noSoundtrack` still means nothing is bundled.
- It is not a parameter of the query: music changes no scene, so choosing a track reloads nothing.
- The view model takes the choice from the first film it loads and then keeps its own, so another child or period
  keeps it. Music and dates changes are saved one after another in one queue, so the newest wins.
- Starting over keeps it, like the dates switch (ADR-0041 §5): it is about how this dad makes films on this iPhone.

### 5. The credits
"Music" credits the chosen track's title in the film's language, then its artist, then "Public domain (CC0)" for a CC0
track.

### 6. New words
| | el | en |
|---|---|---|
| Section | Μουσική (already in the catalog) | Music |
| Button, to listen | Άκουσε τη μουσική | Listen to the music |
| Button, to stop | Σταμάτα τη μουσική | Stop the music |

Titles and moods are in `soundtracks.json` (§1), not in the catalog.

### 7. Tests
- Application: with nothing chosen the film offers every track and has the first; a chosen track is the film's; a
  chosen track no longer bundled gives the first; no track throws `noSoundtrack`.
- Data: the five ids in order, each original by DadSaga, with both titles and moods; each file one audio track of at
  least 95 seconds; a DTO maps its bilingual title and mood; `emptyText` for an empty Greek title, an empty English mood
  or a blank artist; the choice is kept under its own key, and the dates key is untouched.
- Presentation, through the view model as the sheet calls it, with a fake previewer: the tracks and moods in el and en
  with the remembered one chosen; the chosen track's file and localized credit in the script; the choice remembered by
  the next sheet and kept across a child or period; one save queue for dates and music; nothing plays when the sheet
  opens; stop, another track, making the film, closing, leaving the app and a failed load each stop the music; a
  preview that ends by itself offers listening again, and an earlier one ending late doesn't stop a newer one.
- `SagaMusicPreviewer` plays real sound, so it is checked in the simulator, and the silent switch on an iPhone.

## Rejected
- **Five rows, each with its own play button.** Quicker to audition, but five rows push "Make the film" down the sheet.
- **A page of its own** for the music: more navigation, and one more place the preview must stop.
- **Titles in the String Catalog.** They are content and belong with the audio (ADR-0005, ADR-0027 §5); the catalog is
  linked by the widget, which carries no music.
- **A port in Application, implemented in Data, for playing.** Playing sound reads no data and decides nothing; Data
  would import AVFoundation for the screen, and the widget links Data.
- **The view playing on its own.** Stopping for the film, the sheet closing, leaving the app and another track would be
  split between the view and the view model, and couldn't be tested with `swift test`.
- **A second port next to the dates one.** Two ports for one sheet's remembered choices, each with one key.
- **Another audio session category:** `.playback` would play through the silent switch, next to a sleeping child;
  `.ambient` would differ from the film's player.
- **A track chosen by occasion** (the playful one on a birthday): not asked for; the remembered choice is simpler to
  predict.

## Consequences
- The dad hears his film's music before he makes it, and the films he makes next keep it.
- The app carries four more audio files, about four times what the theme adds now. The widget carries none of them.
- Each track should show its mood in its first seconds: the preview and a short film only play its start. Tracks
  should also sound about as loud as each other: a peak at −1 dBFS doesn't make a music box and drums equally loud.
- With the silent switch on, the preview is silent, like the film, and the sheet can't say why.
- The film sheet's snapshot and the Greek credits card change; they are recorded again when snapshots resume
  (ADR-0034). The audit's "Film" step covers the new row.
- One more key in the app's defaults, kept on start over. No stored schema changes (ADR-0026).
