# ADR-0070: The website shows the real app: a demo video per language that ends on the saga film, real screens on the feature cards, and the demo sagas kept in the repository

**Status:** Accepted (2026-11-24, by the owner). Changes ADR-0040 §3 (the timeline clip).

## Context
- The landing page showed the app only in a 10-second clip of the Timeline tab (ADR-0040 §3), recorded on 2026-11-20.
  Since then levels gave way to titles with no XP on screen (ADR-0055), and the clip still showed "+20 XP" on every row.
- The saga film is the app's strongest moment, and the page gave it one sentence inside the timeline section.
- The four feature cards ("Real life is the campaign") were words only: a description and a list of card names.
- Both pages, English and Greek, showed the same English clip.
- The demo saga behind the old clip was made by hand and not kept, so the clip couldn't be recorded again.
- The owner asked for a demo video and a case study with 1.0's features complete, and for a look at whether the site
  shows everything that matters. The owner chose a tour that ends on the film, one per language, the same style for
  the site with more of the app in it, and the case study in the README.

## Decision
1. **A demo video per language replaces the timeline clip.** About 40 seconds of the real app in the simulator, light
   appearance, a clean status bar: home with the hero and both children; a quest done with a photo, its calm reward
   and the title card it brings; a boss fight's survival guide; the timeline for one child and back to both; the saga
   film playing for a few seconds. Encoded to 540 × 1174 H.264 MP4 at 30 fps with no audio track, about 3.1 MB each,
   with a poster of home: `web/assets/demo/demo-{en,el}.mp4` and `demo-{en,el}-poster.jpg`. Each page shows its own
   language. The old clip and its poster are deleted.
2. **The timeline section becomes "Your saga, kept and made into a film"** ("Η saga σου, μαζεμένη και σε ταινία"), and
   its menu link "Your saga" ("Η saga σου"). The video sits in the same phone frame, played by the same script under
   the same rules as ADR-0040 §3: only while in view, never with Reduce Motion, the poster otherwise. Its label
   describes the tour.
3. **Each feature card shows a real screen above its text**: quests on home, a boss and the start of its guide, the
   photo of a first, the world map with the current world. One square JPEG per card and language, 540 × 540, cut in
   the file itself from a full screenshot to the part the card is about
   (`web/assets/screens/{quests,boss,first,worlds}-{en,el}.jpg`), loaded lazily, each with a label that says only
   what the square shows. The "Before the birth" cards stay words only.
4. **What it takes to record again lives in the repository.** `docs/demo/demo-{en,el}.dadsaga` are fictional (Lena
   and Alex, the app's own figures as photos, notes in each saga's language), about 200 KB each, made by playing the
   app and exported with Export and import. The five photos (`docs/demo/photos/`, the bath photo is added on camera)
   and the tools that made them and cut the takes (`Tools/DemoVideo/`, plain Swift scripts, AVFoundation and AppKit
   only) are kept too. `docs/demo/README.md` lists what the sagas hold, how to import them, the shot list, the cut
   ranges, and the recording and encoding steps. Recording again means importing a copy, not building a saga by hand.
5. **The style stays.** The site keeps ADR-0031's and ADR-0039's calm, system look in the app's colours. The game shows
   through the app itself (its screens, the video, the hero), not through new decoration.

## Rejected
- **Only re-recording the timeline clip:** it would fix the XP but keep the film and the rest of the app off the page.
- **One English video for both pages:** the Greek page is for Greek dads, and the app speaks Greek.
- **A more "game" look for the site** (a map-path layout, stronger boss and legendary colours, ornaments): more work,
  a new design to keep in step with the app, and a louder page for a product built on no pressure.
- **Screens for the "Before the birth" cards:** the demo saga's children are born. Words carry that section.

## Consequences
- The landing page is about 2 MB heavier than with the old clip, in its own language only: the video loads its
  metadata first and the screens load as they come into view.
- The video and screens go out of date when the screens they show change, and as the demo saga ages: its ages and
  worlds follow today's date, so Lena leaves the Swamp of No Sleep at 8 months (about March 2027). Recording again
  follows `docs/demo/README.md`.
- The app's own data format changes before the first release don't keep these copies readable (ADR-0060): a change
  that stops them importing makes them again.
- The video, its poster and the screens are light only, while the site follows the visitor's appearance: on a dark
  page they read as the phone in light mode. Two sets would double the work of every recording.
- Nothing but the demo saga's photos may be on camera: the simulator's own sample photos are cleared from its library
  before recording, and the photo picker is cut from the takes.
- Not checked in Safari on an iPhone yet: look at the Cloudflare preview.
