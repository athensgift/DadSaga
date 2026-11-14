# ADR-0013: Child avatars by age stage

**Status:** Accepted

## Context
With families (ADR-0012) the children should be on screen next to the dad, looking roughly their age, gender and
skin tone.

## Decision
- `ChildAvatar` is drawn in SwiftUI like the dad (ADR-0008): no image assets, idle animation, cheers, Reduce Motion.
- **Four stages** from age: baby (0–11 months, sits, has a dummy), toddler (1–2, holds a teddy), preschooler (3–5) and
  kid (6+, school backpack). Younger children have bigger heads and shorter legs. Every stage stands on the same ground
  line of the same canvas, so siblings keep their real height difference.
- **Gender changes hair and accessories** (curl, bow, pigtails, ponytail), not clothing colours. Clothes are coloured
  by stage.
- **Skin tone** uses the same five tones as the dad; hair darkens with the two deepest tones.
- **Family stage on home:** first child on the dad's right, second on his left, and so on. The group shrinks to fit the
  width (four children fit on a 402 pt iPhone and the iPhone Duo cover display). Tapping a child selects them; the
  selected child cheers with the dad after a quest.
- The child editor shows a live preview of the avatar as name, birth date, gender and skin tone change.

## Consequences
- The home screen shows the whole family at a glance.
- More drawing code to maintain; previews in `ChildAvatar.swift` show every stage and gender.
