import Domain
import Foundation

/// What the fixture store written by version 3 holds (ADR-0044 §4): a family and a dad with no look stored, written
/// before the look had columns of its own. Never regenerate the files.
enum StoreV3Fixture {
    static func id(_ text: String) -> UUID { UUID(uuidString: text) ?? UUID() }
    static let nikos = Child(
        id: id("44444444-4444-4444-4444-444444444444"), name: "Νίκος",
        birthDay: .migrated(1_720_000_000), gender: .boy, skinTone: .mediumDark
    )
    static let eleni = Child(
        id: id("55555555-5555-5555-5555-555555555555"), name: "Ελένη",
        birthDay: .migrated(1_760_000_000), gender: .girl, skinTone: .mediumDark
    )
    static let profile = PlayerProfile(children: [nikos, eleni], heroClassID: "h-smart", dadSkinTone: .mediumDark)
    static let events = [
        ProgressEvent(id: id("C0000000-0000-0000-0000-000000000001"), kind: .quest(id: "q-cuddle"), childID: nikos.id,
                      date: Date(timeIntervalSince1970: 1_775_000_000), photoIDs: ["photo-a", "photo-b"]),
        ProgressEvent(id: id("C0000000-0000-0000-0000-000000000002"), kind: .first(id: "f-steps"), childID: eleni.id,
                      date: Date(timeIntervalSince1970: 1_775_100_000), note: "Πρώτα βήματα!")
    ]
    static let outfit = Outfit(choices: [.play: .hidden])

    static var directory: URL {
        URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures/StoreV3")
    }
}
