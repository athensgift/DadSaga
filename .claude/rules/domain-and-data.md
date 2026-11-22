---
paths:
  - "Packages/DadSagaKit/Sources/Domain/**"
  - "Packages/DadSagaKit/Sources/Data/**"
---
- Domain imports only Foundation, and its entities are not `Codable`. Stored and wire formats are DTOs in Data.
- Until the first App Store release nothing has shipped (ADR-0060): `SchemaV1` is the only stored version and is
  changed in place, with no stage and no fixture; the PR says so, and devices running `develop` delete the app first.
  Ids, XP, titles and curves change as the work needs: a rename or removal changes the id with no former id, and a
  dropped card is deleted, not retired.
- From the first App Store release (`docs/RELEASE.md`): a released schema is never edited. A change to a stored property
  is a new `SchemaVn` with a migration stage and a test that opens a store from the previous version, read-write (app)
  and read-only (widget) (ADR-0026). The store fixtures in `Tests/DataTests/Fixtures` are never regenerated, and
  `ShippedContentIDs.json` only grows: a new id adds a line in the same PR, and no line is ever removed (ADR-0048).
