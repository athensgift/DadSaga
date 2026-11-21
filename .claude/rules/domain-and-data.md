---
paths:
  - "Packages/DadSagaKit/Sources/Domain/**"
  - "Packages/DadSagaKit/Sources/Data/**"
---
- Domain imports only Foundation, and its entities are not `Codable`. Stored and wire formats are DTOs in Data.
- Never edit `SchemaV1` or any released schema. A change to a stored property is a new `SchemaVn` with a migration stage
  and a test that opens a store from the previous version, read-write (app) and read-only (widget) (ADR-0026).
- The store fixtures in `Tests/DataTests/Fixtures` (one `Store…` folder per schema version) are never regenerated.
  `ShippedContentIDs.json` only grows: a new id adds a line in the same PR, and no line is ever removed (ADR-0048).
