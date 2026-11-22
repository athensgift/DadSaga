import Foundation
import Testing
@testable import Domain

/// What a saga from a copy must be before it replaces the one on the phone (ADR-0057 §7).
@Suite("A saga from a copy")
struct SagaCopyRulesTests {
    let lena = Child(name: "Λένα", birthDay: .day(2023, 11, 14))
    let nikos = Child(name: "Νίκος", birthDay: nil)

    private func saga(children: [Child]? = nil, events: [ProgressEvent] = []) -> StoredSaga {
        StoredSaga(
            profile: PlayerProfile(children: children ?? [lena], heroClassID: "h-chef"),
            events: events, outfit: Outfit(), kept: .fresh
        )
    }

    private func entry(photos: [String] = [], child: UUID? = nil, id: UUID = UUID()) -> ProgressEvent {
        ProgressEvent(id: id, kind: .first(id: "f-steps"), childID: child ?? lena.id, date: Date(timeIntervalSince1970: 0),
                      photoIDs: photos)
    }

    @Test("Given one to four children with their own ids, when checked, then the saga passes")
    func validFamiliesPass() throws {
        try SagaCopyRules.checked(saga(children: [lena]))
        try SagaCopyRules.checked(saga(children: [lena, nikos, Child(name: "Α", birthDay: nil), Child(name: "Β", birthDay: nil)]))
    }

    @Test("Given no children or five, when checked, then it is refused")
    func childCountIsRefused() {
        #expect(throws: SagaCopyRuleError.childCount) { try SagaCopyRules.checked(saga(children: [])) }
        let five = (1...5).map { Child(name: "Παιδί \($0)", birthDay: nil) }
        #expect(throws: SagaCopyRuleError.childCount) { try SagaCopyRules.checked(saga(children: five)) }
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

        let replaced = saga(events: [first, second]).replacingPhotoIDs(["a": "A", "c": "C"])

        #expect(replaced.events.map(\.photoIDs) == [["A", "C"], []])
        #expect(replaced.events.first?.coverPhotoID == "A")
        #expect(replaced.events.map(\.id) == [first.id, second.id])
    }
}
