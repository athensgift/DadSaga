import Domain
import Foundation

/// What the fixture store written by version 5 holds (ADR-0051 §8): the last store with a `birthDate` column. One child
/// has her day columns; the other's are empty, as in a row the V4 → V5 migration didn't reach, with a birth moment late
/// in the evening UTC, which is already the next day in Athens. Never regenerate the files.
enum StoreV5Fixture {
    static func id(_ text: String) -> UUID { UUID(uuidString: text) ?? UUID() }
    static let maria = Child(
        id: id("88888888-8888-8888-8888-888888888888"), name: "Μαρία",
        birthDay: .day(2025, 9, 14), gender: .girl, skinTone: .mediumDark
    )
    /// Written through `SchemaV5.ChildRecord` with no day: his day is the one this moment falls on in the phone's zone.
    static let petrosBirthMoment = Date(timeIntervalSince1970: 1_786_401_900)
    static let petros = Child(
        id: id("99999999-9999-9999-9999-999999999999"), name: "Πέτρος",
        birthDay: .migrated(1_786_401_900), gender: .boy, skinTone: .mediumDark
    )
    static let look = DadAppearance(hair: .long, hairColor: .brown, beard: .full, glasses: .round)
    static let profile = PlayerProfile(
        children: [maria, petros], heroClassID: "h-cool", dadSkinTone: .mediumDark, dadAppearance: look
    )
    static let events = [
        ProgressEvent(id: id("E0000000-0000-0000-0000-000000000001"), kind: .quest(id: "q-w1-night-shift"),
                      childID: maria.id, date: Date(timeIntervalSince1970: 1_790_000_000),
                      photoIDs: ["photo-x", "photo-y", "photo-z"]),
        ProgressEvent(id: id("E0000000-0000-0000-0000-000000000002"), kind: .first(id: "f-smile"),
                      childID: petros.id, date: Date(timeIntervalSince1970: 1_790_100_000), note: "Χαμογέλασε!"),
        ProgressEvent(id: id("E0000000-0000-0000-0000-000000000003"), kind: .boss(id: "b-w1-first-fever"),
                      childID: maria.id, date: Date(timeIntervalSince1970: 1_790_200_000))
    ]
    static let outfit = Outfit(choices: [.care: .item("g-mug"), .play: .hidden])

    static var directory: URL {
        URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures/StoreV5")
    }
}
