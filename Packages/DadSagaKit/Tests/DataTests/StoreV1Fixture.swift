import Domain
import Foundation

/// What the fixture store written by version 1 holds (ADR-0040 §2): entries with one photo and one without, written
/// before the schema changed for several photos. Never regenerate the files.
enum StoreV1Fixture {
    static func id(_ text: String) -> UUID { UUID(uuidString: text) ?? UUID() }
    static let mia = Child(
        id: id("33333333-3333-3333-3333-333333333333"), name: "Μία",
        birthDate: Date(timeIntervalSince1970: 1_740_000_000), gender: .girl, skinTone: .medium
    )
    static let profile = PlayerProfile(children: [mia], heroClassID: "chef", dadSkinTone: .light)
    /// The four events as version 1 wrote them, each with at most one photo.
    static let events = [
        ProgressEvent(id: id("B0000000-0000-0000-0000-000000000001"), kind: .quest(id: "q-cuddle"), childID: mia.id,
                      date: Date(timeIntervalSince1970: 1_770_000_000), photoID: "photo-quest"),
        ProgressEvent(id: id("B0000000-0000-0000-0000-000000000002"), kind: .boss(id: "b-night"), childID: mia.id,
                      date: Date(timeIntervalSince1970: 1_770_100_000), photoID: "photo-boss"),
        ProgressEvent(id: id("B0000000-0000-0000-0000-000000000003"), kind: .first(id: "f-steps"), childID: mia.id,
                      date: Date(timeIntervalSince1970: 1_770_200_000), note: "Πρώτα βήματα!", photoID: "photo-first"),
        ProgressEvent(id: id("B0000000-0000-0000-0000-000000000004"), kind: .quest(id: "q-bath"), childID: mia.id,
                      date: Date(timeIntervalSince1970: 1_770_300_000))
    ]

    static var directory: URL {
        URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures/StoreV1")
    }
}
