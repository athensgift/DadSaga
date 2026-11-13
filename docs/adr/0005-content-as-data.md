# ADR-0005: Game content as data (JSON), validated at load

**Status:** Accepted

## Context
Worlds, quests, bosses and firsts will grow and change often, and they are bilingual.

## Decision
- Content lives in JSON files bundled in the `Data` module, with every text field as `{ "el": …, "en": … }`.
- JSON is decoded into DTOs and mapped to Domain entities. `ContentValidator` checks unique ids and valid world references,
  and the mapper rejects unknown skills. Tests also check ages and empty strings.
- Progress is stored as events referencing content ids. Unknown ids are ignored, so removing content never crashes.

## Consequences
- Content can be edited without touching Swift. It could later be fetched remotely.
- The JSON is the single source for both iOS and the future Android client.
- Content strings use their own localisation path, not String Catalogs (UI strings still use String Catalogs).
