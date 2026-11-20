import Domain
import Foundation

/// What the fixture store written before versioned schemas holds (ADR-0026). Never regenerate the files.
enum StoreFixture {
    static func id(_ text: String) -> UUID { UUID(uuidString: text) ?? UUID() }
    static let lena = Child(
        id: id("11111111-1111-1111-1111-111111111111"), name: "Λένα",
        birthDate: Date(timeIntervalSince1970: 1_750_000_000), gender: .girl, skinTone: .light
    )
    static let nikos = Child(
        id: id("22222222-2222-2222-2222-222222222222"), name: "Νίκος",
        birthDate: Date(timeIntervalSince1970: 1_700_000_000)
    )
    static let profile = PlayerProfile(children: [lena, nikos], heroClassID: "chef", dadSkinTone: .medium)
    static let events = [
        ProgressEvent(id: id("A0000000-0000-0000-0000-000000000001"), kind: .quest(id: "q-cuddle"), childID: lena.id,
                      date: Date(timeIntervalSince1970: 1_760_000_000), note: "το λάτρεψε"),
        ProgressEvent(id: id("A0000000-0000-0000-0000-000000000002"), kind: .boss(id: "b-night"), childID: nikos.id,
                      date: Date(timeIntervalSince1970: 1_760_100_000)),
        ProgressEvent(id: id("A0000000-0000-0000-0000-000000000003"), kind: .first(id: "f-steps"), childID: lena.id,
                      date: Date(timeIntervalSince1970: 1_760_200_000), note: "Τρία βήματα!", photoIDs: ["photo-1"])
    ]
    static let outfit = Outfit(choices: [.care: .item("cloth"), .play: .hidden])

    static var directory: URL {
        URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures/StoreBeforeV1")
    }
}
