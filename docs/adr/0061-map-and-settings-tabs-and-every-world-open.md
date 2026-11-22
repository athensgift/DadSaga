# ADR-0061: The world map and Settings as tabs, two columns when open flat, every world open, and the map and Settings above and below the fold

**Status:** Accepted (2026-11-22; the owner accepted the open worlds, the tab order and "Map", the hero above
Settings and tap-to-preview on the folded map). The owner tried home on the iPhone Duo and asked for four things: no split at the fold
while the Duo lies open flat; the map and Settings as tabs instead of buttons placed per device; every world open at any
time, saying when it is ideal instead of when it unlocks; and laptop layouts for the map, Settings, "Your hero" and "My
family". Designed by the architect. Supersedes ADR-0045, and ADR-0058 §1–§5. Changes ADR-0006 §3, ADR-0011, ADR-0017,
ADR-0019, ADR-0030 §1 and §8, ADR-0043 §3 and §8, ADR-0044 §8, ADR-0050 §4, ADR-0053 (the map before the birth),
ADR-0055 §3 (what ends the Undo, and its time through a turn), ADR-0056 §1, §2 and §4, and ADR-0057 §6–§8 (Export data
is a page of the Settings tab).

## Context
- Apple: "When iPhone Duo is fully open, the division is inactive, so `reservedRegions(kind:options:layoutDirectionBehavior:)`
  returns no division regions." Home asks for inactive ones too (`.includeInactive`, `whileFlat`), only to keep its
  half-open panes while the Duo lies flat (ADR-0045, ADR-0056 §2). Open flat and upright, home is split at a hinge the
  dad can't feel.
- The map and Settings have three placements, each a navigation stack of its own (ADR-0056, ADR-0058): a large bar in
  one column, an inline bar with no title side by side, and a glass capsule over the adventure above and below a fold.
  Two of the three work around how UIKit sets scroll insets under a bar that changes on a screen that stays.
- Settings is a sheet with a close button; home reloads when it closes, and its unsaved-work scope ends then (ADR-0030
  §1, ADR-0050 §4). The map is a sheet built on demand (`HomeViewModel.openMap`).
- A tab bar lets people "quickly switch between sections of the view while preserving the current navigation state
  within each section" (HIG, Tab bars). The system places it on every display (at the side on the Duo's cover display
  and on its side), and tab bars "already adjust for the fold" (`ReservedRegion`). Apple's own `Tab` example has a
  Settings tab. The HIG asks for tab labels of "single words whenever possible".
- Home's tab already reloads each time it appears, as the timeline's does (ADR-0017): its `.task` runs again when the
  dad comes back from another tab.
- A world the child hasn't reached is locked on the map ("Unlocks in 15 months"). `HomeOverview` shows only reached
  worlds, and `UnlockRules.isOffered` hides every card above the child's age, so a world ahead would be empty even if it
  opened. Recording has no age rule: `ProgressRecorder` checks only that the card exists.
- Some cards assume their age: "The chef" (World 2, from 10 months) is "Cook a meal you both eat".
- Apple: scrolling containers "don't split their content around a division by default. When the device is partially
  open, a row or item can run across the fold." ADR-0043 §8 kept the map and Settings whole, so half-open they have rows
  across the fold. A `Form` is one scroll view: no row of it can be kept off the fold.

## Decision

### 1. Home: two columns when open flat; split only while half-open
- `HomeArrangement.make(width:fold:)`: a fold across home (half-open like a laptop) is `.stacked`; otherwise 600 pt and
  wider is `.columns`, narrower is `.column`. Open flat and upright, the Duo shows two columns, as in ADR-0011.
- The flat fold goes: `whileFlat`, `HorizontalFold.divisions(active:all:whileFlat:)` and the `.includeInactive` query.
  The reader takes the active divisions only, Apple's default.
- Folding an upright Duo swaps its columns for rows again, as ADR-0043 first had it. The two scroll views stay the same
  views through `AnyLayout`, so each keeps where it was scrolled to. Apple advises to "favor small adjustments over
  rearrangement"; the owner chose the columns.
- **The bar:** one column keeps the navigation bar with its large title, and nothing in it. Two panes, side by side or
  above and below, have no bar; the title heads the hero's pane (ADR-0011, ADR-0043 §3). Home no longer builds a stack
  per kind of bar (ADR-0058 §5): with no toolbar and only "large" or "none", the bar is shown with new scroll views
  each time, which is when UIKit sets their insets. The title mode stays named (ADR-0058 §7), and home still reads its
  width and the fold around its stack (ADR-0058 §6).
- `HomeButtonsPlacement`, `HomeArrangement.buttons`, the capsule, both toolbar items and the adventure's bottom margin
  for the capsule go. ADR-0056 §3 (the hero fills what the title leaves above the fold) stays.

### 2. Four tabs: Adventure, Map, Timeline, Settings

| Tab | Symbol | el | en |
|---|---|---|---|
| Adventure | `figure.and.child.holdinghands` | Περιπέτεια | Adventure |
| Map | `map` | Χάρτης | Map |
| Timeline | `clock.arrow.circlepath` | Χρονολόγιο | Timeline |
| Settings | `gearshape` | Ρυθμίσεις | Settings |

- The map sits next to Adventure, whose worlds it chooses; Settings is last, as in Apple's apps. "Map" is the one new
  label (one word, HIG); the map's own title stays «Χάρτης κόσμων» / "World map".
- **Who owns what.** The root builds home's, the timeline's and Settings' presenters once, when home's state begins,
  and drops them for onboarding. Home's presenter owns the map: it is rebuilt with every load of home, for the child
  home shows; `openMap` and `closeMap` go. The map's tab reloads home when it appears and when the app comes back from
  the background, so a change made in Settings shows there too. With several children the map has the child picker;
  a child chosen there is home's.
- **Choosing a world** shows it on home (`showWorld(id:)`) and the root moves to Adventure.
- **When home reloads.** Every time Adventure or the map appears. Leaving Settings for either shows what "Your hero",
  the wardrobe or "My family" changed; `settingsDismissed` goes.
- **Settings** has no close button; its title is large on a flat display. Its pages are pushed as before and, like every
  tab, it is where the dad left it when he comes back.
- **The Undo** on home's bar ends when the dad leaves Adventure for any other tab, the map and Settings included: the
  root's hook on the selected tab keeps calling `leftForAnotherTab` for every tab but Adventure (ADR-0055 §3). A
  Settings page can remove the child the card belongs to, and the map leaves for Adventure with a reload.
- **The Undo's time no longer starts again when the device turns.** It did only because each kind of bar had its own
  stack (ADR-0058 §5), so a turn rebuilt the bar. An offer now has one clock, from the card it follows, however home
  is laid out: a turn is not a second chance to undo, and folding never restarted it either. If the fallback in
  Consequences is ever needed, a turn between one column and two panes restarts it again, and only then.
- **Unsaved work.** "My family" reports to `UnsavedWork` under `UnsavedScope.settings` as before. Its hold ends when it
  is saved, when the dad discards, or when its page is freed; no sheet closes any more.
  - While "My family" holds changes it hides the tab bar, as it hides the system's back button (ADR-0050). Home's and
    the timeline's editors are sheets that cover the tab bar; hidden, the page stays on screen as long as it holds, so
    re-tapping Settings can't pop it (and drop the changes unasked) and the dad can't leave it on another tab.
  - A link that arrives while an editor holds changes still waits (ADR-0050 §4), always in front of the dad: the
    holding editor is on screen. The root never switches tabs under an open sheet.
  - Once nothing is held, the root moves to Adventure and hands the link to home, as before. Settings closes its own
    question and alert as the link opens (start over, the mail fallback), as the timeline closes its film sheet; its
    pages stay where they were.
- **Export data (ADR-0057).** Its page, once a sheet, is pushed in the Settings tab. It hides the tab bar, as the sheet
  covered it, so it is left only by Back, and only when it isn't working (§8 holds). Its copies are deleted when the dad
  leaves the page (§6: no longer when Settings closes, which a tab never does), and when an imported saga builds every
  tab anew (§7: Settings is built again, at its first page, rather than closed).
- **Start over** switches the root to onboarding, which takes the four tabs away, and ends every hold
  (`UnsavedWork.endAll`), so nothing left of the old saga can hold the new saga's links. Adventure is selected again.
- Deep links are unchanged (`AppLink`: a quest, a moment or a child, opened on Adventure).

### 3. Every world open
- **No world is locked.** Age still decides the current world ("You are here"), what home shows by default, the
  widget's and the notification's quest, the film's chapters and offers, and which cards of the current world have come.
- **A world ahead** (one the child's age hasn't reached) that the dad opens offers every card of its own and every
  evergreen card of the worlds before it, whatever their ages, as if the child were at its end. Retired cards and
  cards for another family still don't show. The rule is Domain's: `UnlockRules.quests(for:in:age:family:)` and
  `bosses(for:in:age:family:)` lift the age check for a world ahead. `isOffered(_:in:age:family:)` keeps the age for
  links from outside, which come from the current world. `unlockedWorlds` becomes `reachedWorlds`.
- **Doing a card ahead** works as any card: `CompleteQuestUseCase` and `DefeatBossUseCase` record any card the catalog
  knows, a boss once per child. It counts for XP, the title, the skills, the timeline and the map's counts for its own
  world, and an Undo takes it back. The film puts each entry in the chapter of the child's age on its day, not of the
  card's world.
- **On the map** a world ahead opens like any other, at full strength; its marker shows its number, no lock. In place
  of "Unlocks in N months" it says when it is ideal, from its own start. Once the dad has done something there, its
  progress follows on a line of its own. A world the child has reached never shows the line: nothing is ever late.
- **On home**, a world ahead says the same line under its name, above "Back to the current world".

  | Key | el | en | When |
  |---|---|---|---|
  | `Ideally after the birth` | Ιδανικά μετά τη γέννα | Ideally after the birth | a world that starts at 0 months |
  | `Ideally from %lld months` (plural) | Ιδανικά από τον %lld μήνα · Ιδανικά από τους %lld μήνες | Ideally from %lld month · Ideally from %lld months | a start before 24 months |
  | `Ideally from %@ years` | Ιδανικά από τα %@ χρόνια | Ideally from %@ years | from 24 months: "2", "3½" |
  | `Open this world` | Άνοιξε αυτόν τον κόσμο | Open this world | the map's folded preview (§4) |
  | `Map` | Χάρτης | Map | the tab |

  "Unlocks in %lld months" and "Opens after the birth" go. A catalog test checks that no key or text speaks of
  unlocking or locks, as one already does for XP.
- **ADR-0006.** Rule 3 said worlds unlock by age. Now none locks; age still sets the current world and paces its cards,
  and the child's development still gates nothing. "Ideally from" names a start, never an end, and replaces a countdown.
  XP stays for what the dad does. Nothing is lost, there is no streak and no deadline.
- **Content.** `fact-check` reads every card of Worlds 1–4 as a dad would before its age, so no card reads as advice
  to do now what is safe only later; a card that needs it gets the age in its own words.

### 4. Above and below the fold
Only while the Duo is half-open like a laptop. On a flat display every screen is one page, as before.
- **The map:** as the timeline (ADR-0043 §7). The path lies below the fold, with the child picker over it. One world
  stands above, large: its number, ages, name, tagline, the ideal or progress line, its tag, and "Open this world". It is
  the world the dad tapped, or the one home shows. Below the fold a tap shows a world above, marked in the path and
  "selected" for VoiceOver; on a flat display a tap opens it, as before. Choosing a world leaves the map, so a tap
  below the fold that opened it at once would leave the upright half nothing to show. Which world is shown above is
  the view's own state.
- **Settings:** the dad's hero above, drawn as on "Your hero" (class and look, no gear) and read through that page's own
  query, `GetHeroChoiceUseCase`; the whole form below, scrolling on its own. The form can't keep a row off the fold, so it
  goes whole into the half on the table, where every control is near the hands. The upright half shows who Settings is
  about, and he stays there as the dad pushes "Your hero" or the wardrobe; "My family" puts the children there. The
  hero is decoration, hidden from VoiceOver. A container like `ReadAndActPanes` holds it, with the form as its second
  view and never inside a scroll view: the same form in both layouts, so it keeps where it was scrolled to and an open
  menu.
- **"Your hero":** as the wardrobe: the hero above, the skin tone, the look and the hero grid below.
- **"My family":** the children as they are being edited, and the footnote, above; their cards, "Add a child", the
  partner and an error below. With the keyboard up, the lower part alone shows above it (ADR-0043 §2). Save stays in
  the bar.
- The reminder page, onboarding, a first's choice and the film's choices stay as they are (ADR-0043 §8). So does the book
  pose: a fold that runs down a screen splits nothing.
- Folded, the map's and Settings' titles are inline: a large title would collapse as a pane scrolls and move the fold.

### 5. Where the code goes

| Layer | Adds | Changes or removes |
|---|---|---|
| Domain | `UnlockRules.isAhead(_:at:)` | `unlockedWorlds` → `reachedWorlds`; `quests` and `bosses(for:…)` lift the age in a world ahead |
| Application | `HomeOverview.isShowingWorldAhead` | `Adventure.reachedWorlds`; `HomeOverview` shows any world of the catalog by id |
| Data | | none; a card's text only if `fact-check` asks |
| DesignSystem | | `whileFlat`, `HorizontalFold.divisions(active:all:whileFlat:)`, `.includeInactive` go |
| Presentation | `RootTab.map`, `.settings`; `WorldMapView`, `WorldMapPreview`, the path from `WorldMapSheet`; the form's fold container; `UnsavedWork.endAll()` and the scopes held | `HomeArrangement`, `HomeView`, `HomeView+Buttons`, `HomeView+Events`, `HomeViewModel+WorldMap`, `+Links`; `WorldMapItem.Status.locked` → `.ahead`; `HomeContent.mapTitle`, `.settingsTitle` go; `SettingsScreens`, `HomeButtonsPlacement`, `WorldMapSheet` go; `SettingsView`, `SettingsViewModel` (no close, not `Identifiable`, the hero's query); `RootViewModel`, `RootView`; the catalog |
| App | | `makeSettingsViewModel` passes `GetHeroChoiceUseCase` |
| Tests | | the audit and the appearance UI test open the map and Settings from the tab bar; the snapshots build home and Settings without a close |

No stored data, schema, content id, Info.plist key or required-reason API changes: the privacy manifests and pages stay
as they are (ADR-0051).

## Rejected
- **Keeping the buttons, in the bar everywhere:** the bar comes back on two panes, which moves the fold's place
  (ADR-0043 §3), and the placement per device with it.
- **The map or Settings in a tab bar accessory:** an accessory is for something like the MiniPlayer that plays across
  tabs, not a section.
- **Asking before the dad leaves "My family" for another tab:** a tab switch the app refuses, with the question far from
  its page. The waiting link already keeps his words; showing him the page is enough.
- **A world ahead offered at its start age:** part of it would stay hidden, and it would look locked again. **Every
  card's own age kept:** a world ahead would be empty.
- **"Ideally from" on every card ahead:** the same line on every card of a world; the world says it once, and the
  cards that need it say their age in their own words.
- **The map's lower pane scrolling the upper one:** what the dad reads would move under his eyes as he scrolls, with
  scrolls kept in step by hand. Tapping to show a world above is what the timeline already does.
- **Settings across the fold**, or **two forms split at a section** (controls on the upright half), or **About above**
  (little to read, and rarely what the dad came for).

## Consequences
- Home has no buttons. The map and Settings are a tap away from anywhere, wherever the system puts the tabs.
- Four tabs, each a single word in English.
- Folding an upright Duo swaps columns for rows, a large change the HIG and Apple's fold guidance advise against.
- If turning an iPhone or the Duo leaves home's large title collapsed (as ADR-0058 measured for an inline bar turned
  large), home goes back to a stack per kind of bar, `.id(arrangement.hasPanes)`, at the cost of §2's Undo clock on
  those turns.
- The Undo also ends on a trip to the map or Settings, and runs on through a turn of the device. The root's view
  model tells home each time the dad leaves Adventure (`RootViewModel.onLeftAdventure`), so it is tested there.
- A dad can read and do any world's cards at any time; a dad on the way can play World 1 before the birth.
- A share sheet left open in Settings stays over home when a link opens: the system offers no way to close it.
- The README's rule 3 and the roadmap's line on ADR-0045 change with the code.

## Verification status
Built and tested (2026-11-22). Drawn in the simulator on the iPhone Duo (closed, half-open, open flat) and the
iPhone 17: home in two columns open flat, the map and Settings tabs, "Your hero" and "My family" half-open, the
keyboard on "My family". Still to check:
- the Undo bar up while the iPhone 17 turns: it goes when it would have without the turn;
- the Duo upright: open flat (two columns, no bar), folded to 90° and back (rows and columns, each pane where it was
  scrolled to), turned on its side and back; the iPhone 17 turned and back, its large title expanded each time;
- four tabs on the cover display's side bar, on its side, and at the accessibility text sizes;
- the map half-open: tapping between worlds, "Open this world", two children; a world ahead on home with its line, its
  cards done, undone and counted on the map;
- Settings half-open, with an Appearance menu open while folding; "Your hero" and "My family" half-open, with the
  keyboard up;
- "My family" holding changes: no tab bar; a widget link waits, then opens after saving; start over, then a link;
- a link while Settings' start-over question or mail alert is up (it closes as home opens the link's sheet).

When the snapshots run again: home in two columns, the map tab and the Settings tab are recorded again; the audit
reaches the map and Settings from the tab bar.
