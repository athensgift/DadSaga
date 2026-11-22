# ADR-0063: The saga copy's row and page are named "Export and import"

**Status:** Accepted (2026-11-22). The owner tested the page and found its name misleading: the row and the title said
only "Export data", though the page also imports. Changes ADR-0057 §8 (the row and page name, and the onboarding
sentence that points to it). Numbered 0063 because another branch takes 0060.

## Context
- ADR-0057 §8 names the Settings row and its page "Export data" / «Εξαγωγή δεδομένων». The page has two parts:
  exporting the saga to a file and importing one. A dad looking for the way to bring a copy back doesn't find it
  under a name that says only export.
- Since ADR-0061 the page is pushed in the Settings tab, so its title is what the dad reads at the top of it.

## Decision
- The row under "Your data" and the page's title: **"Export and import" / «Εξαγωγή και εισαγωγή»**. The row and the page
  read the same, so the dad knows where he is.
- Inside the page, the two section headers stay as ADR-0057 has them: "Export data" / «Εξαγωγή δεδομένων» and
  "Import data" / «Εισαγωγή δεδομένων». Onboarding's button and sheet stay "Import data".
- Onboarding's import text points to the new name in Settings:
  - en: "If you have a copy of your saga from Export and import in Settings, choose it here and pick up where you
    left off."
  - el: «Αν έχεις αντίγραφο της ιστορίας σου από την Εξαγωγή και εισαγωγή στις Ρυθμίσεις, διάλεξέ το εδώ και
    συνέχισε από εκεί που είχες μείνει.»
- The support and privacy pages (en and el) name the page the same way.

## Alternatives
- "Copy of your saga" / «Αντίγραφο της ιστορίας σου»: it names the file well, but not what the page does. ADR-0057
  chose plain words for the actions, and the dad looking for import still has to guess.
- Two rows, one for each: the page is one flow with one set of files to clean up when it closes (ADR-0057 §6,
  ADR-0061 §2), so splitting it is a bigger change for a naming problem.

## Consequences
- A test checks that the row, the page title and the onboarding text use the same name, in el and en.
- The Settings snapshot images still show "Export data" until snapshots are re-recorded (paused, CLAUDE.md).
