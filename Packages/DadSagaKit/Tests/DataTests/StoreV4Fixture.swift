import Domain
import Foundation

/// What the fixture store written by version 4 holds (ADR-0048): the last store whose birth dates are instants, with
/// one born at noon UTC and one born late in the evening UTC, which is already the next day in Athens. Never
/// regenerate the files.
enum StoreV4Fixture {
    static func id(_ text: String) -> UUID { UUID(uuidString: text) ?? UUID() }
    static let anna = Child(
        id: id("66666666-6666-6666-6666-666666666666"), name: "Άννα",
        birthDay: .migrated(1_741_003_200), gender: .girl, skinTone: .medium
    )
    static let lefteris = Child(
        id: id("77777777-7777-7777-7777-777777777777"), name: "Λευτέρης",
        birthDay: .migrated(1_779_319_800), gender: .boy, skinTone: .medium
    )
    static let look = DadAppearance(hair: .curly, hairColor: .grey, beard: .short, glasses: .round)
    static let profile = PlayerProfile(
        children: [anna, lefteris], heroClassID: "h-cool", dadSkinTone: .medium, dadAppearance: look
    )
    static let events = [
        ProgressEvent(id: id("D0000000-0000-0000-0000-000000000001"), kind: .quest(id: "q-w1-night-shift"),
                      childID: anna.id, date: Date(timeIntervalSince1970: 1_780_000_000),
                      photoIDs: ["photo-a", "photo-b"]),
        ProgressEvent(id: id("D0000000-0000-0000-0000-000000000002"), kind: .first(id: "f-smile"),
                      childID: lefteris.id, date: Date(timeIntervalSince1970: 1_780_100_000), note: "Το πρώτο χαμόγελο"),
        ProgressEvent(id: id("D0000000-0000-0000-0000-000000000003"), kind: .boss(id: "b-w1-first-fever"),
                      childID: lefteris.id, date: Date(timeIntervalSince1970: 1_780_200_000))
    ]
    static let outfit = Outfit(choices: [.care: .item("g-mug")])

    static var directory: URL {
        URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures/StoreV4")
    }
}
