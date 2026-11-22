import Domain
import Foundation

/// What the fixture store written by version 6 holds (ADR-0055 §5): the last store from before titles. One child is
/// born and one is not yet. The boss is one card worth 100 care XP: title 1 by cards, but the old rule had earned the
/// burp cloth (50 care XP), which the wardrobe wears. Never regenerate the files.
enum StoreV6Fixture {
    static func id(_ text: String) -> UUID { UUID(uuidString: text) ?? UUID() }
    static let eleni = Child(
        id: id("AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"), name: "Ελένη",
        birthDay: CalendarDay(year: 2026, month: 3, day: 2), gender: .girl, skinTone: .light
    )
    static let baby = Child(
        id: id("BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"), name: "Μπέμπης", birthDay: nil, gender: .boy, skinTone: .light
    )
    static let look = DadAppearance(hair: .short, hairColor: .black, beard: .short, glasses: .none)
    static let profile = PlayerProfile(
        children: [eleni, baby], heroClassID: "h-cool", dadSkinTone: .light, dadAppearance: look, hasPartner: false
    )
    static let events = [
        ProgressEvent(id: id("F0000000-0000-0000-0000-000000000001"), kind: .boss(id: "b-w1-first-fever"),
                      childID: eleni.id, date: Date(timeIntervalSince1970: 1_790_000_000), note: "Τα καταφέραμε",
                      photoIDs: ["photo-a", "photo-b"])
    ]
    static let outfit = Outfit(choices: [.care: .item("g-burp-cloth")])

    static var directory: URL {
        URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures/StoreV6")
    }
}
