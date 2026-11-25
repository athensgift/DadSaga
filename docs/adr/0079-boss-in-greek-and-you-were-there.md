# ADR-0079: "boss" in Greek everywhere, and a boss for when life changes reads "You were there"

**Status:** Accepted (2026-11-25). From the review of 2026-11-25; both wordings are the owner's choice. Changes the
Greek wording in ADR-0030 (start over) and ADR-0057 (export and import), and ADR-0053 §5 (what a recorded situational
boss shows).

## Context
- The Greek cards, App Store text and website say «boss» and «bosses». Five Greek strings of the app said «αφεντικό» and
  «αφεντικά»: the map's and the film's counts, start over, and the two texts about a copy. The screenshots and the
  text beside them disagreed.
- Once recorded, every boss read "Defeated · …" / «Νικήθηκε · …». The bosses for when life changes are the two homes, a
  death in the family and a move: "The Hand That Holds" says itself that this boss can't be beaten.

## Decision
1. **The Greek word is «boss», plural «bosses»**, neuter, with Greek articles where one is needed («κάθε boss», «το
   boss»), in every string, as in the cards, the listing and the site. The badge stays «BOSS».
2. **A boss with `situational: true` is never "Defeated".** Once recorded it reads «Ήσουν εκεί · …» / "You were there ·
   …", with its badge, on its card and in its sheet. Every other boss keeps «Νικήθηκε» / "Defeated".
3. The words are interface strings, chosen by the flag: a card that becomes situational changes its label by itself.

## Consequences
- A new Greek string that names a boss says «boss».
- Wherever the app starts to say a boss was beaten (a new screen, the widget), it uses the same words
  (`HomeStrings.recordedText`).
