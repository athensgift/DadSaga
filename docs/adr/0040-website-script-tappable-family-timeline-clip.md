# ADR-0040: The website gets its own script, a family that cheers, and a clip of the real timeline

**Status:** Proposed (2026-11-20). The owner asked for Super Dad and the baby to react to a tap as in the app, and for
the timeline to look real, ideally as a short video. The owner agreed to JavaScript for it. Changes ADR-0031 §1 (no
JavaScript, the launch art as the hero image) and ADR-0039 (CSS-only motion).

## Context
- ADR-0031 kept the site free of JavaScript and enforced it with `script-src 'none'`. That was a choice, not a limit
  of Cloudflare Pages. A tap that makes a figure cheer and then rest needs a few lines of script.
- On home, tapping the hero or a child makes them cheer for 450 ms: arms up, mouth open, a little jump on a spring
  (`HeroAvatar`, `ChildAvatar`). The figures are drawn in code, so the site can't run them. `Tools/LaunchLogo` already
  renders them to PNG for the launch screen and the site.
- The timeline section was an HTML mock of the Timeline tab. It looked close, but not like the app.

## Decision
1. **Our own script, nobody else's.** `_headers` moves from `script-src 'none'` to `script-src 'self'`: one file,
   `web/assets/site.js`, served from the site. No third-party scripts, no analytics, no requests. The privacy policy
   doesn't change.
2. **The family cheers when tapped.**
   - `Tools/LaunchLogo` renders Super Dad and the baby separately, each at rest and cheering, light and dark, from one
     canvas: `web/assets/family/{dad,baby}-{rest,cheer}-{light,dark}.png`. Each figure is cropped to the box that holds
     both its poses, so the swap moves nothing. The tool prints each box as a share of the family, for `site.css`.
   - Each figure is a `<button>` with a label ("Super Dad. Tap him to cheer."). A tap swaps rest for cheer for 450 ms,
     as in the app, with a small spring (CSS) unless Reduce Motion is on, and a 10 ms vibration where the browser has
     one. The group keeps the old image's description, and a hint under it says what to tap.
   - The single hero images `super-dad-{light,dark}.png` go: nothing else uses them. `og.png` is unchanged.
3. **The timeline is a recording of the app.**
   - About 10 seconds of the real Timeline tab in the simulator, with a small demo saga (two children, a boss, two
     quests with photos, a first with a photo, a quest for the other child) going from all children to one, to the
     other, and back. The sample photos are the app's own figures on coloured backgrounds, made for the clip.
   - Encoded to 540 × 1174 H.264 MP4 (about 1.5 MB) with a poster frame (`web/assets/timeline/`), shown in the phone
     frame without the HTML mock and its CSS.
   - The script plays it while at least a quarter of it is on screen and pauses it otherwise. It never plays with
     Reduce Motion, and without the script, which leaves the poster: a still of the same screen.
   - The `<video>` has a label that describes what it shows. It has no sound.
4. ADR-0039's CSS motion stays, except the timeline mock's row and icon reveals, which went with the mock.

## Consequences
- The site can now run code we write, so the CSP still blocks every injected or third-party script.
- When the timeline's look changes, the clip is out of date until someone records it again. That is manual: a demo
  saga in a simulator, `simctl io recordVideo`, then the encode. The family images update with every `LaunchLogo` run.
- The landing page is about 1.7 MB heavier with the clip. The video loads its metadata first (`preload="metadata"`).
- Not checked in Safari yet: look at the preview on an iPhone.
