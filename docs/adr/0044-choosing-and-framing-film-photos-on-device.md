# ADR-0044: Choosing and framing the saga film's photos with Vision, on the device, as the film is made

**Status:** Proposed (2026-11-20). The owner asked for Apple's on-device Vision to choose an entry's further photos
for the film and to keep faces in view; drafted by the architect. The owner then chose both halves, and for the
framing: the children before the adults, and a close-up on them of at most 1.25, always zooming in on a child (§3).
Changes ADR-0042 §6 (which of an entry's further photos fill its places in the film), ADR-0037 §3 (where a photo's
glide goes, and how close it gets), and ADR-0036 §3 and §5 (`FilmKit` aims a camera at a part of a picture; the film's
photos are looked at while the film is made).

## Context
- A film shows an entry's cover with its scene, then up to three of its further photos
  (`SagaPacing.morePhotosPerEntry`), and thins further photos first when it runs over 90 seconds (ADR-0042 §6). Both
  choices go by position:
  - `Cutter.morePhotos(of:)` takes `photoIDs.dropFirst().prefix(3)`, so an entry's fifth photo is never in a film;
  - the thinning keeps photos evenly spread over the film's whole list of further photos, so within one entry it keeps
    whichever positions the spread lands on (the second and the fourth, say), not the best of them.
- Every photo is drawn whole over a blurred copy of itself (`FilmFit.fitOverBlur`, ADR-0037 §2) and glides between
  zoom 1 and 1.12 towards a fixed point, the middle across and 45 % down (`SagaFilmTimelineBuilder.closeUp`). At the
  close end of the glide about 5 % is cut from the left and the right of a photo that fills the frame's width, and
  about 10 % from the bottom of one that fills its height (almost nothing from the top). A face near those edges is cut:
  rarely, but not never.
- Vision's Swift API is on the device and needs iOS 18 and macOS 15; the package's minimums are iOS 26 and macOS 26
  (ADR-0002), so no availability check is needed:
  - `CalculateImageAestheticsScoresRequest` gives an `ImageAestheticsScoresObservation`: `overallScore`, "within the
    range of -1 and 1, where -1 is least desirable and 1 is most desirable", and `isUtility`, "images that are not
    necessarily of poor image quality, but may not have memorable or exciting content" (screenshots, receipts,
    documents).
  - `DetectFaceRectanglesRequest` gives `FaceObservation`s, each with a `boundingBox` (`NormalizedRect`, its origin at
    the lower left; `CoordinateOrigin.upperLeft` and `verticallyFlipped()` convert).
  - `GenerateAttentionBasedSaliencyImageRequest` gives a `SaliencyImageObservation` whose `salientObjects` are
    rectangles with bounding boxes.
  - `ImageRequestHandler` (a `Sendable` final class) performs any number of requests on one image, each `async throws`.
    The requests and the observations are `Sendable` structs.
- Developers report that in the Simulator the aesthetics request returns the same result for every image, without an
  error ([Apple Developer Forums 758847](https://developer.apple.com/forums/thread/758847)). CI's virtual Mac may have
  no Neural Engine. Nothing promises that a request runs, or that its numbers stay the same from one OS release to the
  next.
- Photos are JPEG files in the folder the app shares with the widget (ADR-0016, ADR-0023). A film is never stored
  (ADR-0036 §6). Every change to the stored schema is a new version with a migration (ADR-0026).
- iOS 26 runs on iPhone 11 (A13) and later. Apple publishes no timings for these requests.
- ADR-0006: nothing may judge the child, and nothing may turn the dad's photos into a score he is measured by.

## Decision

### 1. What changes, and what doesn't
- Two things only: **which of an entry's further photos fill its places in the film**, and **where a photo's glide goes
  and how close it gets**.
- Unchanged:
  - the cover, which is the dad's choice (ADR-0042 §1), and every card drawn over it;
  - how many scenes a film has and how long each lasts;
  - how quests and bosses are thinned (ADR-0036 §2);
  - the order of photos everywhere in the app;
  - thumbnails, the photo viewer, `WholePhoto` and the cover above the fold (ADR-0043): they show a photo whole or as
    the dad arranged it, and a whole photo has nothing to frame.

### 2. Choosing an entry's further photos
- **How many places** each entry keeps is decided as today: up to three, and, when the film is too long, by the even
  spread over the film's further photos (ADR-0042 §6). A film's timing never depends on Vision.
- **Which photos** fill them, from the entry's further photos (up to four): photos that are not utility before those
  that are, then the higher `overallScore`. Equal ratings, and any entry with a photo that has no rating, keep the
  photos today's rule keeps. The chosen photos play in the dad's order.
- Ratings are compared only between photos of the same entry: never across entries, children or films.
- A utility photo is never left out to make room that isn't needed. When an entry has a place for every further photo,
  all of them play; a utility photo only goes first when places are short. A scan, a hospital bracelet or the child's
  drawing can be "utility" and still matter.
- Domain decides it: `SagaStoryboard.photoChoices` lists the entries with more further photos than places, with the
  photos today's rule keeps; `SagaStoryboard.choosingPhotos(by:)` refills those places from `[String: PhotoRating]`.
  Pure and deterministic; with no ratings it returns the storyboard as it was.

### 3. Framing a photo
- **Children before adults.** Vision has no age estimate (checked in the iOS 27.2 SDK), but `ClassifyImageRequest`'s
  labels include `baby`, `child`, `teen` and `adult`. Each face found is classified on the head and shoulders around it
  (its box grown by half its size on every side, as the request's region of interest, so nothing is cropped or copied),
  and is a **child** when `baby` + `child` outscores `adult` + `teen`. Only an age group, for one photo, for one film:
  never who the person is.
- **The subject** (Domain, `PhotoSubject.region`): the children's faces as one region, each grown by about a third of
  its size, leaving out faces less than a third of the tallest one's height (people in the background). With no face
  classed as a child, all the faces, by the same rule, so a misclassified child is framed as with plain face
  detection. With no face, the union of the attention-based salient objects; otherwise none.
- **The close-up is on the subject, at most 1.25.** The close end of a glide is the closest camera on the subject,
  capped at 1.25 (`SagaFilmPhotoLoader.subjectZoomLimit`), never below 1. The subject stays whole: when it is too large
  for the cap, the zoom is lower, never the subject cut. Without a subject, today's 1.12 towards today's fixed point.
  Zoom 1 still shows the whole photo.
- **A child is always zoomed in on.** Glides alternate in and out as before, except that a photo where a child is found
  always glides in, from the whole photo to the child (the owner's choice: a glide out moves away from the child). Two
  neighbouring photos may then both glide in. Photos of adults only, of no face, or with no subject keep the
  alternation. To know it, every face is classified, a photo with one face too.
- **`FilmKit` knows the geometry, not the faces.** `FilmCamera.closest(on:pictureSize:spec:fit:maxZoom:)` takes a
  `FilmRegion` (unit coordinates from the top left) and returns that camera. Along a side the picture fills, the camera
  moves towards the focus only as far as keeps the picture's edge out of the frame; along a side it doesn't fill (a
  portrait photo across a wide film), the picture stays in the middle, as today. `FilmKit` still knows no faces and no
  game (ADR-0036 §3).
- **The motion comes with the photo.** A clip's photo loader returns a `FilmPhoto`: the image and, optionally, the
  motion that replaces the clip's own, since the camera can only be aimed once the photo is known.
- Reduce Motion keeps photos still, as before, and the subject is not looked for.
- Not done: cropping a photo to fill the frame around its subject. The owner chose the close-up capped at 1.25
  instead, so ADR-0037 §2 holds: every photo is shown whole at zoom 1.

### 4. When: while the film is made, quickly, and never stored
- The owner asked for it to be quick. So the two halves run where they cost least:
  - **Choosing** runs first, when the dad taps "Make the film", inside the film's task (Cancel and leaving the app stop
    it, ADR-0037 §4). It rates only the further photos of the entries in `photoChoices` (none in most films), read at
    512 px, two at a time.
  - **Framing** runs in the photo loader, which already reads each photo one clip ahead of the clip being written
    (ADR-0036 §3). The subject is found on the photo's bytes the loader has just read, while the encoder writes the
    clip before; the film waits for it only when looking takes longer than writing a clip.
- **Only what can change the film is looked at:** faces and their age group for every photo that glides; saliency only
  with no face; aesthetics only for the photos in `photoChoices`.
- **Nothing is written:** no column, no file beside the photo, no cache on disk. So there is no schema version
  (ADR-0026), and nothing for deleting an entry, starting over, the widget's folder, export or a future sync to carry.
  When Vision's model changes with an OS update, the next film simply uses it.
- The film's query (`GetSagaFilmUseCase`, ADR-0028) doesn't look at photos, so opening the sheet and changing a choice
  stay as fast as today.
- **Rejected: analysing each photo once when it is saved,** kept in a file beside it or in a column. Photos saved
  before this change need the film-time path anyway, so a cache adds a second path; its files must go with every
  delete and with starting over, and be thrown away with each new model. Saving would be slower too: five photos
  already take about a second (ADR-0042).
- **Cost, estimated, not measured:** faces take tens of milliseconds a photo, and each classified face about as much
  again; aesthetics about 50 ms at 512 px. Framing overlaps the drawing, so a film should take only a little longer
  than today, plus the choosing, which most films skip. It is measured on the oldest iPhone at hand, with the owner's
  own photos, before this ADR is accepted.

### 5. Layers (ADR-0007, ADR-0036 §5, ADR-0037 §1)
- **Domain:** `PhotoRating`, `PhotoRegion`, `PhotoFace`, `PhotoSubject.region` (the subject rule), `SagaPhotoChoice`,
  `SagaStoryboard.photoChoices` and `choosingPhotos(by:)`.
- **Application:** the port `PhotoAnalyzer` (`rating(of:)`, `faces(in:)`, `salientObjects(in:)`);
  `ChooseSagaFilmPhotosUseCase`, which reads the candidates through `PhotoStore` and refills the film's storyboard;
  `FindPhotoSubjectUseCase`, which asks for faces, then saliency, and applies the subject rule.
- **Data:** `VisionPhotoAnalyzer`, the only file that imports Vision.
- **FilmKit:** `FilmRegion`, `FilmCamera.closest(on:…)`, `FilmPhoto` and `FilmPhotoLoader`.
- **Presentation:** `SagaFilmViewModel` chooses the photos, then builds the script and renders it; the renderer's
  `SagaFilmPhotoLoader` finds each gliding photo's subject and aims its glide. The view model still imports no SwiftUI,
  FilmKit or Vision.
- **`AppContainer`** wires one `VisionPhotoAnalyzer` into both use cases.

### 6. When Vision can't
- Each request is performed on its own, so one that fails doesn't take the others with it. A failure, a request this
  device doesn't support, or a photo that can't be read leaves that part empty; nothing is thrown but a cancel.
- No rating: the entry keeps today's photos. No subject: today's camera. A request that answers the same for every
  photo, as in the Simulator, ties them all, and ties keep today's photos. **Without Vision, a film is exactly today's
  film.**

### 7. Nothing is judged (ADR-0006)
- No score, flag, face or region is ever shown, spoken, stored, logged or sent. No word in the app or in the film says
  that photos were rated or chosen.
- A rating only chooses among the dad's own further photos of one entry, for one film. It never touches the cover, the
  order of photos in the app, XP, the timeline, the widget, the offer card or a reminder, and nothing ever asks for
  "better" photos.
- Nothing about the child is measured. Face detection finds rectangles, not who is in them: no recognition, no
  expressions, no "best smile". The only thing told about a face is child or adult, so the camera goes to the
  children: it is kept for the length of one film, never shown, and never compared between photos or films.
- The age group is a guess and can be wrong; a wrong guess only moves the camera, as a missed face does.
- All of it runs on the device (ADR-0004) and is gone when the film is made.

### 8. Tests
- **Domain:** the best three of four further photos play, in the dad's order; a utility photo plays while there is
  room and goes first when there isn't; with places short, each entry keeps as many photos as before and the film's
  scenes and seconds don't change; the cover is never replaced; no ratings, equal ratings or one unrated photo give
  today's storyboard. The subject: the children's faces and not the adults' when both are there; all faces when
  none is a child; small faces left out; saliency without faces; none without either; always inside the photo.
- **FilmKit:** the closest camera on a small focus stops at 1.25, on it; a focus larger than the close-up lowers the
  zoom and stays whole; a focus at a picture's edge keeps the edge out of the frame; a picture narrower than the frame
  stays in the middle; a photo that brings its own motion moves the clip by it.
- **Application:** with a fake analyser, the best further photos fill an entry's places and only its candidates are
  read; unrated photos give the sheet's film; a film where everything fits reads no photo; the subject is the child,
  not the adult, and what draws the eye when there is no face.
- **Data:** Vision's box from the lower left maps to the same box from the top left; bytes that aren't an image give
  empty answers; on a generated image, whatever Vision answers stays in range. No test expects Vision's numbers.
- **Presentation:** the film made by the sheet plays an entry's best further photos; a photo with a subject glides to
  it at 1.25; one without glides as today; under Reduce Motion it stays still.
- Every test of the film, and the snapshots, use a fake analyser or none: Vision's output never decides whether a test
  passes. No snapshot image changes (the cards have no camera).

## Consequences
- A film leans towards the dad's most memorable photos of each entry, and his fifth photo can now be in it. It is never
  longer, and never has fewer photos, than before.
- The camera goes to the children and closer than before, up to 1.25, and a face that Vision finds is never cut. A
  face it misses is framed as today; a child it takes for an adult is framed with the others.
- How well `ClassifyImageRequest` tells a child's face crop from an adult's is not known: it is checked on the owner's
  own photos on a device, with the timing, before this ADR is accepted.
- Making a film takes a little longer: the measurement in §4 decides whether the cache or the overlap is needed.
- Two films of the same saga can differ after an OS update, if Vision's model changed. Nothing is stored, so nothing
  goes stale.
- The film differs between the Simulator and a phone. The Simulator shows today's choices, and the Simulator's
  subjects may differ from the phone's.
- The widget links `Data`, so it links Vision too. It never calls it; Vision is a system framework, so the widget does
  not grow.
- No stored schema, content or UI text changes.
