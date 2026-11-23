import Foundation
import Testing
@testable import Domain

/// What a saga from a copy must be before it replaces the one on the phone (ADR-0057 §7).
@Suite("A saga from a copy")
struct SagaCopyRulesTests {
    let lena = Child(name: "Λένα", birthDay: .day(2023, 11, 14))
    let nikos = Child(name: "Νίκος", birthDay: nil)

    private func saga(children: [Child]? = nil, removed: [Child] = [], events: [ProgressEvent] = []) -> StoredSaga {
        StoredSaga(
            profile: PlayerProfile(children: children ?? [lena], heroClassID: "h-chef", removedChildren: removed),
            events: events, outfit: Outfit(), kept: KeptStanding()
        )
    }

    private func entry(photos: [String] = [], child: UUID? = nil, id: UUID = UUID()) -> ProgressEvent {
        ProgressEvent(id: id, kind: .first(id: "f-steps"), childID: child ?? lena.id, date: Date(timeIntervalSince1970: 0),
                      photoIDs: photos)
    }

    @Test("Given one, four or six children with their own ids, when checked, then the saga passes")
    func validFamiliesPass() throws {
        try SagaCopyRules.checked(saga(children: [lena]))
        try SagaCopyRules.checked(saga(children: [lena, nikos, Child(name: "Α", birthDay: nil), Child(name: "Β", birthDay: nil)]))
        try SagaCopyRules.checked(saga(children: (1...6).map { Child(name: "Παιδί \($0)", birthDay: nil) }))
    }

    @Test("Given no child, or only removed ones, when checked, then it is refused")
    func noChildIsRefused() {
        #expect(throws: SagaCopyRuleError.noChild) { try SagaCopyRules.checked(saga(children: [])) }
        #expect(throws: SagaCopyRuleError.noChild) { try SagaCopyRules.checked(saga(children: [], removed: [lena])) }
    }

    @Test("Given a removed child beside the family, when checked, then it passes; with a family child's id or no name, not")
    func removedChildrenAreChecked() throws {
        try SagaCopyRules.checked(saga(children: [lena], removed: [nikos]))
        let twin = Child(id: lena.id, name: "Άλλη", birthDay: nil)
        #expect(throws: SagaCopyRuleError.duplicateChild) { try SagaCopyRules.checked(saga(removed: [twin])) }
        let unnamed = Child(name: " ", birthDay: nil)
        #expect(throws: SagaCopyRuleError.emptyChildName) { try SagaCopyRules.checked(saga(removed: [unnamed])) }
    }

    @Test("Given entries by two authors, when checked, then it passes")
    func anyAuthorPasses() throws {
        let partners = ProgressEvent(authorID: UUID(), kind: .boss(id: "b-colic"), childID: lena.id, date: Date())
        try SagaCopyRules.checked(saga(events: [entry(), partners]))
    }

    @Test("Given two children with one id or an empty name, when checked, then it is refused")
    func brokenChildrenAreRefused() {
        let twin = Child(id: lena.id, name: "Άλλη", birthDay: nil)
        #expect(throws: SagaCopyRuleError.duplicateChild) { try SagaCopyRules.checked(saga(children: [lena, twin])) }
        let unnamed = Child(name: "  ", birthDay: nil)
        #expect(throws: SagaCopyRuleError.emptyChildName) { try SagaCopyRules.checked(saga(children: [unnamed])) }
    }

    @Test("Given two entries with one id, six photos on one, or one photo on two, when checked, then it is refused")
    func brokenEntriesAreRefused() {
        let id = UUID()
        #expect(throws: SagaCopyRuleError.duplicateEntry) {
            try SagaCopyRules.checked(saga(events: [entry(id: id), entry(id: id)]))
        }
        #expect(throws: SagaCopyRuleError.tooManyPhotos) {
            try SagaCopyRules.checked(saga(events: [entry(photos: (1...6).map(String.init))]))
        }
        #expect(throws: SagaCopyRuleError.sharedPhoto) {
            try SagaCopyRules.checked(saga(events: [entry(photos: ["a"]), entry(photos: ["a"])]))
        }
    }

    @Test("Given an unknown card and hero, a child born after today and a child who left, when checked, then it passes")
    func whatTheAppAlreadyHandlesPasses() throws {
        let tomorrow = Child(name: "Μαρία", birthDay: CalendarDay(Date().addingTimeInterval(86_400 * 2), in: .gmt))
        var copy = saga(children: [tomorrow], events: [entry(child: UUID())])
        copy.profile.heroClassID = "h-from-the-future"
        copy.events.append(ProgressEvent(kind: .quest(id: "q-from-the-future"), childID: tomorrow.id, date: Date()))

        try SagaCopyRules.checked(copy)
    }

    @Test("Given new ids for some photos, when replacing them, then each entry keeps its order and loses the others")
    func replacingPhotoIDsKeepsTheOrder() {
        let first = entry(photos: ["a", "b", "c"])
        let second = entry(photos: ["d"])

        let partners = ProgressEvent(authorID: UUID(), kind: .boss(id: "b-colic"), childID: lena.id, date: Date())

        let replaced = saga(removed: [nikos], events: [first, second, partners]).replacingPhotoIDs(["a": "A", "c": "C"])

        #expect(replaced.events.map(\.photoIDs) == [["A", "C"], [], []])
        #expect(replaced.events.map(\.authorID) == [.testDad, .testDad, partners.authorID])
        #expect(replaced.profile.removedChildren == [nikos])
        #expect(replaced.events.first?.coverPhotoID == "A")
        #expect(replaced.events.map(\.id) == [first.id, second.id, partners.id])
    }
}
