# ADR-0036: The saga film: drawn frame by frame on the device, from the timeline, never stored

**Status:** Accepted (2026-11-19). The owner approved the plan for Phase 3½ of the roadmap. Changes ADR-0007 (a
presenter may hold a drawing protocol), ADR-0030 §8 (starting over also forgets the film offers), and ADR-0033 and
ADR-0034 (the film sheet joins the audit and the snapshots).

## Context
- Phase 3½ asks for a short film of the saga, made on the device: Ken Burns photos, a title card for each first, bundled
  music, end credits, offered on a birthday, when a world is completed and on demand, and shared in 9:16 and 16:9.
- The saga is an event log; XP, the timeline and moments are derived from it (ADR-0017, ADR-0021). Photos are JPEG files
  of at most 2048 px (ADR-0016, ADR-0022). Nothing leaves the device unless the dad sends it (ADR-0004).
- The roadmap names `AVMutableComposition` with Core Animation overlays (`AVVideoCompositionCoreAnimationTool`). That
  route needs a carrier video track under still photos, keeps every photo layer's image in memory for the whole
  export, builds `CALayer` trees that are not `Sendable`, and can only be checked by playing its output. Developers
  report exports hanging with an animation tool attached. `AVMutableVideoComposition` is deprecated in the iOS 26 SDK
  (replaced by `AVVideoComposition(configuration:)`), and `AVAssetWriterInputPixelBufferAdaptor` in the iOS 27 SDK.
- iOS 26 and macOS 26 (the package's minimums) add `async` writer inputs: `AVAssetWriter.inputPixelBufferReceiver(for:
  pixelBufferAttributes:)`, whose `append(_:with:)` waits until the input is ready; `inputReceiver(for:)` for sample
  buffers; `AVAssetReader.outputProvider(for:)`; and `Sendable` pixel buffers and pools (`CVMutablePixelBuffer`,
  `CVReadOnlyPixelBuffer`, `CVMutablePixelBuffer.Pool`). `CGImage` and `CIContext` are `Sendable`.
- `ImageRenderer` draws SwiftUI text, shapes and images, but not views that Core Animation composites (materials,
  glass, players).
- ADR-0006: "a world completed" must not mean its quests being finished, and an offer must not turn into a deadline or a
  nag.

## Decision
1. **What a film shows.** One child and one period: a year of life, a world the child has lived in, or everything so
   far. Scenes run oldest first:
   - an opening card with the child's name, the period, and the dad's hero next to the child, as they were at the
     end of the period;
   - in a film that spans more than one world, a chapter card each time the child's world changes (by age);
   - a card for every first captured in the period, with its photo and the dad's note (up to two lines);
   - a badge card for each boss;
   - quest photos as a montage;
   - credits.

   Left out: XP, levels and totals, anything not captured, the child's age at a first, anything about what may come
   next, and other children. The credits list roles, and count only what the dad did in the period: quests and bosses.
2. **At most 90 seconds** (`SagaPacing`, Domain). Quest photos are thinned evenly first, then bosses without a photo,
   then bosses with one. Firsts are never dropped; if they still don't fit, their cards get shorter, down to 3 seconds
   each, so only firsts can take a film past 90 seconds.
   - Every period and occasion starts at midnight of a day counted from the child's birth day: a birth date keeps the
     time of day it was entered.
3. **Drawn frame by frame, not with Core Animation overlays.** A new package target, `FilmKit`, uses Apple frameworks
   only and knows nothing of the game:
   - Each frame is composed with Core Image (Ken Burns, cross-fades, cards on top) into a buffer from the writer's
     pool, and appended through `PixelBufferReceiver`.
   - The music is an `AVMutableComposition`, looped or trimmed to the film's length. It is read through
     `AVAssetReaderAudioMixOutput`, with a fade-out ramp, and appended through `inputReceiver(for:)`.
   - Video and audio are appended in two child tasks, so the writer can interleave them.
   - Photos load one clip ahead, so at most two are decoded at once.
   - Output: H.264 High at 30 fps, 1080×1920 or 1920×1080, with AAC audio, as MP4 tagged BT.709.
   - Encoding is `@concurrent`, so it runs off the main actor whatever the compiler's default (ADR-0034 §7).
4. **Cards are SwiftUI views, rendered with `ImageRenderer`** on the main actor at the film's pixel size:
   - always dark, with no materials and no glass;
   - their type is scaled to the frame, not to Dynamic Type: a film is a fixed canvas, not a screen;
   - avatars are drawn with `avatarsAreStill`;
   - content titles come from the JSON (ADR-0005), and the film's own words from the String Catalog (ADR-0027);
   - names stand alone and are never inflected.
5. **Layers.**
   - Domain decides what goes in: `SagaStoryboard`, `SagaPeriod`, `SagaOccasion`, `SagaPacing`.
   - Application reads it in one query, `GetSagaFilmUseCase` → `SagaFilm` (ADR-0028).
   - Data bundles the music: `soundtracks.json` and `BundledSoundtrackRepository`.
   - Presentation draws it. `SagaFilmViewModel` builds a display script and hands it to a `SagaFilmRendering` protocol,
     whose implementation renders the cards and calls `FilmKit`. The view model imports neither SwiftUI nor
     AVFoundation.

   The film is a view of the saga, so drawing it belongs with the views (ADR-0007's drivers ring), not behind a use
   case.
6. **Never stored.** A film is rendered on demand into a temporary folder, played from there with `VideoPlayer` and
   shared with `ShareLink`. It is deleted when the sheet closes and before the next film starts. So it always matches
   the saga, keeps no space, and needs no schema change; starting over has no film files to delete.
   `NSPhotoLibraryAddUsageDescription` (el and en) is added for the share sheet's "Save Video".
7. **Triggers (ADR-0006).**
   - On demand from the timeline, always.
   - On home, one calm card when the child has a birthday or grows into the next world (age only, never quests or bosses
     done), and has at least one entry in that period. It shows for 30 days from the occasion, until the dad answers.
     There is only ever one such card: the newest occasion, and a world's end before a birthday on the same day. Once
     the dad answers it, no older occasion takes its place.
   - No notification, badge, count or word about time. "Not now" never asks about that occasion again.
   - Answers are kept in the app's defaults (`SagaOfferRepository`). Starting over clears them.
8. **Music.** One bundled track, at least 95 seconds long, credited in the film and in `soundtracks.json` with its
   licence. It is either original, made without Apple Loops (GarageBand's licence forbids repackaging loops as music
   beds), or CC0 with its licence page archived in the repository.
9. **Reduce Motion**, as set when the film is made: the photos stay still, scenes change by cross-fade only, and the
   avatars don't move.
10. **Leaving the app stops the film.** iOS doesn't run an app's GPU work in the background, and developers report that
    `BGContinuedProcessingTask`'s GPU resource is not offered on iPhone. The sheet then offers to make the film again.

## Consequences
- The renderer can be tested exactly in `swift test`: frame counts, duration, size, colours at chosen times, and
  cancellation. The film's content rules have Domain tests. Neither needs a simulator.
- Making a film takes seconds on the phone, every time. It can't be watched later without being made again, and it
  can't be found in the app once the sheet closes. The dad keeps it by sharing it or saving it to Photos.
- One more package target (`FilmKit`), a bundled audio file, and a licence to keep with it.
- The writer's async receivers are new. One unanswered forum report has `PixelBufferReceiver.append` never returning.
  If that shows up in our tests, the deprecated adaptor remains a stopgap until Apple fixes it.
- Whether CI's virtual Mac can encode (VideoToolbox, Metal) is checked in the first `FilmKit` change. Without Metal,
  Core Image renders on the CPU.
- A shared film carries the dad's notes and photos. The sheet shows the whole film before it can be shared, and the
  file holds no location and no birth date.
