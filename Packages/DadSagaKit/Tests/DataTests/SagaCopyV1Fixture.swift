import Domain
import Foundation

/// What the format-1 copy in `Fixtures/SagaCopyV1` holds (ADR-0057 §4), with its three photos beside it as
/// `<id>.jpg`. Format 1 shipped with the screens for it: never record it again (ADR-0057 §4).
enum SagaCopyV1Fixture {
    static func id(_ text: String) -> UUID { UUID(uuidString: text) ?? UUID() }

    static let photoIDs = [
        "11111111-1111-1111-1111-111111111111", "22222222-2222-2222-2222-222222222222",
        "33333333-3333-3333-3333-333333333333"
    ]
    static let eleni = Child(
        id: id("AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"), name: "Ελένη 🌟",
        birthDay: CalendarDay(year: 2025, month: 2, day: 28), gender: .girl, skinTone: .mediumDark
    )
    static let baby = Child(
        id: id("BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"), name: "Μπέμπης", birthDay: nil, gender: .boy, skinTone: .light
    )
    static let copy = SagaCopy(
        saga: StoredSaga(
            profile: PlayerProfile(
                children: [eleni, baby], heroClassID: "h-cool", dadSkinTone: .dark,
                dadAppearance: DadAppearance(hair: .long, hairColor: .red, beard: .short, glasses: .round),
                hasPartner: false
            ),
            events: [
                ProgressEvent(id: id("E0000000-0000-0000-0000-000000000001"), kind: .boss(id: "b-w1-first-fever"),
                              childID: eleni.id, date: Date(timeIntervalSinceReferenceDate: 790_000_000.25),
                              note: "Τα καταφέραμε 💪\nμαζί", photoIDs: [photoIDs[0], photoIDs[1]]),
                ProgressEvent(id: id("E0000000-0000-0000-0000-000000000002"), kind: .quest(id: "q-w2-car-seat"),
                              childID: eleni.id, date: Date(timeIntervalSinceReferenceDate: 790_100_000)),
                ProgressEvent(id: id("E0000000-0000-0000-0000-000000000003"), kind: .first(id: "f-from-the-future"),
                              childID: baby.id, date: Date(timeIntervalSinceReferenceDate: 790_200_000), note: "",
                              photoIDs: [photoIDs[2]])
            ],
            outfit: Outfit(choices: [.care: .item("g-burp-cloth"), .play: .hidden]),
            kept: KeptStanding(titleID: "t-new-to-the-journey", seenTitleID: "t-new-to-the-journey")
        ),
        answeredOccasionIDs: ["eleni/birthday/1", "eleni/world/w2"],
        madeAt: Date(timeIntervalSinceReferenceDate: 790_300_000.5)
    )

    static var directory: URL {
        URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures/SagaCopyV1")
    }

    static var file: URL { directory.appending(path: "copy.dadsaga") }

    static func photo(_ id: String) -> URL { directory.appending(path: "\(id).jpg") }
}
