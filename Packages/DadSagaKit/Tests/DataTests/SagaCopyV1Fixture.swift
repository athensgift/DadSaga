import Domain
import Foundation

/// What the format-1 copy in `Fixtures/SagaCopyV1` holds (ADR-0057 §4), with its three photos beside it as
/// `<id>.jpg`. Until the first App Store release format 1 changes in place, and the copy is recorded again when it
/// changes; that release records it once more with the build submitted, and from then on it is never recorded again
/// (ADR-0057 §4, ADR-0060 §1, §5).
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
    /// Removed from the family in a co-op version (ADR-0065 §4), with an entry by the partner.
    static let iris = Child(
        id: id("CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC"), name: "Ίρις", birthDay: CalendarDay(year: 2023, month: 6, day: 1),
        gender: .girl, skinTone: .medium
    )
    static let heroID = id("D0000000-0000-4000-8000-00000000000D")
    static let partnerID = id("F0000000-0000-4000-8000-00000000000F")
    static let copy = SagaCopy(
        saga: StoredSaga(
            profile: PlayerProfile(
                id: heroID, children: [eleni, baby], heroClassID: "h-cool", dadSkinTone: .dark,
                dadAppearance: DadAppearance(hair: .long, hairColor: .red, beard: .short, glasses: .round),
                hasPartner: false, removedChildren: [iris]
            ),
            events: [
                ProgressEvent(id: id("E0000000-0000-0000-0000-000000000001"), authorID: heroID,
                              kind: .boss(id: "b-w1-first-fever"),
                              childID: eleni.id, date: Date(timeIntervalSinceReferenceDate: 790_000_000.25),
                              note: "Τα καταφέραμε 💪\nμαζί", photoIDs: [photoIDs[0], photoIDs[1]]),
                ProgressEvent(id: id("E0000000-0000-0000-0000-000000000002"), authorID: heroID, kind: .quest(id: "q-w2-car-seat"),
                              childID: eleni.id, date: Date(timeIntervalSinceReferenceDate: 790_100_000)),
                ProgressEvent(id: id("E0000000-0000-0000-0000-000000000003"), authorID: heroID,
                              kind: .first(id: "f-from-the-future"), childID: baby.id,
                              date: Date(timeIntervalSinceReferenceDate: 790_200_000), note: "", photoIDs: [photoIDs[2]]),
                ProgressEvent(id: id("E0000000-0000-0000-0000-000000000004"), authorID: partnerID,
                              kind: .first(id: "f-smile"), childID: iris.id,
                              date: Date(timeIntervalSinceReferenceDate: 790_250_000), note: "Χαμογέλασε")
            ],
            outfit: Outfit(choices: [.care: .item("g-burp-cloth"), .play: .hidden]),
            kept: KeptStanding(titleID: "t-new-to-the-journey", seenTitleID: "t-new-to-the-journey")
        ),
        answeredOccasionIDs: ["eleni/birthday/1", "eleni/world/w2", "iris/birthday/1"],
        madeAt: Date(timeIntervalSinceReferenceDate: 790_300_000.5)
    )

    static var directory: URL {
        URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures/SagaCopyV1")
    }

    static var file: URL { directory.appending(path: "copy.dadsaga") }

    static func photo(_ id: String) -> URL { directory.appending(path: "\(id).jpg") }
}
