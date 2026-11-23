# Demo sagas and the site video

Two fictional sagas for recording the demo video on dadsaga.app (and later App Store previews): `demo-en.dadsaga`
and `demo-el.dadsaga`. Same family in both, written in the saga's language. No real people or photos: the photos are
the app's own figures (`web/assets/family/`) on coloured backgrounds.

- Super Dad, with a partner. Lena / Λένα (girl, born 12 Jul 2026) and Alex / Άλεξ (boy, born July 2025).
- Lena: quest "Your own lullaby" (photo, note), boss "The Sleep That Vanished" (note), first smile (7 Sep, photo,
  note), first laugh (22 Oct, note).
- Alex: quest "Park expedition" (photo, note), first steps (14 Aug, photo, note).
- Title: level 3, "Dad with a few tricks" (6 cards, 245 XP). The next quest done on camera ("Bath master", 25 XP)
  brings "Steady hands" and the changing bag, so the title card shows in the video.

The quests and the boss are dated the day the saga was made (24 Nov 2026): only firsts can be dated back. Ages and
worlds follow today's date, so after a few months Lena leaves the Swamp (0–8 months) and the shots change.

## Import a demo saga into the simulator

```bash
UDID=2EC499D0-4D7C-4CE2-BF9D-2B5558A4BFB8   # the booted iPhone 17
FILES="$(xcrun simctl get_app_container $UDID com.apple.DocumentsApp groups | awk -F'\t' '/FileProvider.LocalStorage/{print $2}')/File Provider Storage"
cp docs/demo/demo-en.dadsaga "$FILES/"          # shows in Files › On My iPhone
xcrun simctl uninstall $UDID com.athinodoros.dadsaga
xcrun simctl install $UDID <path to the built DadSaga.app>
xcrun simctl launch $UDID com.athinodoros.dadsaga -AppleLanguages '(en)' -AppleLocale en_US
#   Greek: -AppleLanguages '(el)' -AppleLocale el_GR
```

In onboarding tap **Import data › Choose a copy**, pick the file, **Import**. Then on home answer the weekly reminder
offer with **No, thanks** (it isn't in the copy, and accepting would show the notification prompt), and make sure the
child picker shows Lena. The bath photo the video adds must be in the simulator's Photos:

```bash
xcrun simctl addmedia $UDID <scratch>/photos/*.jpg
```

The five photos were made by a short AppKit script that draws `web/assets/family/{dad,baby}-{rest,cheer}-light.png`
on vertical gradients (1200 × 1500 JPEG): park (dad cheer + baby cheer, sky to grass), nap (baby rest, dusk purple),
first steps (baby cheer, peach), walk (dad rest + baby rest, mint), bath (two babies, light blue).

To type Greek in the simulator (the pasteboard is overwritten by the Mac's), launch the app with
`-AppleKeyboards '("el_GR@sw=Greek;hw=Automatic")'`: hardware keys then type the Greek layout (`;` is the tonos,
`w` is ς, `j` is ξ, `u` is θ, `c` is ψ, `v` is ω).

## Shot list (both languages, about 45 s)

1. Home: Super Dad, Lena and Alex, level 3; slow scroll to Lena's quests in the Swamp of No Sleep.
2. "Bath master": the sheet with its tip, Note or photos, Add photos, the bath photo picked, I did it.
3. The calm reward: "Your care grew", Saved · Undo, and the title card "You became Steady hands · You got: Changing
   bag". Scroll up: the hero now carries the bag, "Level 4 · Steady hands".
4. Switch to Alex, scroll to the bosses, open "The Velcro Phase" and its survival guide, scroll it, close.
5. Timeline: All, Lena, All (Nov, Oct, Sep, Aug).
6. Film button › Saga film sheet (Lena, the whole saga, vertical) › Make the film › the film plays: title card,
   first smile, first laugh…

## Recording and encoding

Light appearance and a clean status bar:

```bash
xcrun simctl ui $UDID appearance light
xcrun simctl status_bar $UDID override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl io $UDID recordVideo --codec=h264 --force take.mp4   # in the background; stop with: pkill -INT -f recordVideo
xcrun simctl status_bar $UDID clear
```

The tour was played once per language without stopping, logging a timestamp before each tap. The recording only
has frames when the screen changes, so the encode joins the kept ranges and repeats the latest frame at 30 fps.
No ffmpeg on the Mac: three small AVFoundation tools, kept in the session scratchpad (not in the repo):

- `cut <take.mp4> <out.mp4> <bitrate> <start-end>…` — `AVMutableComposition` of the ranges,
  `AVAssetReaderVideoCompositionOutput` scaled to 540 px wide (540 × 1174), `AVAssetWriter` H.264 High, 650 kbit/s,
  constant 30 fps, no audio, fast start.
- `poster <take.mp4> <seconds> <out.jpg>` — one frame at 540 × 1174, JPEG 0.82.
- `sheet <video> <out.jpg> <t>…` — contact sheet of frames, to choose the cuts.

Ranges used (seconds in the raw takes):

```text
en: 9.0-13.5 26.4-28.2 36.5-37.6 60.0-64.0 72.0-74.0 83.3-87.8 97.5-100.5 115.8-117.6 150.2-152.4 160.1-162.6
    178.2-179.6 182.3-183.0 203.6-207.6 208.9-210.4 211.4-213.9 219.3-226.5          poster at 9.0
el: 9.8-14.2 24.2-26.0 34.7-36.2 61.5-65.0 66.1-68.3 82.0-89.3 104.2-106.6 127.1-129.9 139.5-142.0 159.2-160.8
    162.5-163.3 166.0-168.2 182.0-184.4 184.8-186.2 187.0-188.9 198.0-199.0 204.8-210.0  poster at 9.8
```

Cuts drop the photo picker's first load, the long scroll to the bosses and most of the film's making (a second of
its progress stays).

Outputs: `web/assets/demo/demo-{en,el}.mp4` and `demo-{en,el}-poster.jpg`.

Feature stills for the site (`web/assets/screens/{quests,boss,first,worlds}-{en,el}.jpg`):
`xcrun simctl io $UDID screenshot --type=png x.png`, then `sips -Z 1174 -s format jpeg -s formatOptions 80`
(boss: 66) and the PNG deleted.
