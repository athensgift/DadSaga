import Application
import Domain
import Foundation
import Testing

/// The day a first can have (ADR-0053 §3, ADR-0078 §4): who it is offered to, and from which day.
extension MomentUseCaseTests {
    @Test("Given a first of after the birth, when capturing it on the birth day, then it is stored; the day before, refused")
    func fromTheBirthDay() async throws {
        await #expect(throws: MomentError.dateBeforeBirth) {
            try await capture.execute(request(date: birth.addingTimeInterval(-1)), now: today)
        }
        #expect(try await repository.fetchEvents().isEmpty)

        _ = try await capture.execute(request(date: birth), now: today)
        #expect(try await repository.fetchEvents().map(\.date) == [birth])
    }

    @Test("Given a first before birth, when capturing it for a born child a year before the birth, then it is stored")
    func aFirstBeforeBirthAnyDay() async throws {
        let before = birth.addingTimeInterval(-365 * 86_400)
        let picture = CaptureMomentRequest(firstID: Self.picture.id, childID: child, date: before)

        _ = try await capture.execute(picture, now: today)

        #expect(try await repository.fetchEvents().map(\.date) == [before])
    }

    @Test("Given a child not born yet, when capturing, then a first before birth is stored and any other is not offered")
    func beforeTheBirthOnlyItsFirsts() async throws {
        await #expect(throws: MomentError.notOffered(firstID)) {
            try await capture.execute(request(child: Self.coming.id), now: today)
        }
        #expect(try await repository.fetchEvents().isEmpty)

        let picture = CaptureMomentRequest(firstID: Self.picture.id, childID: Self.coming.id, date: today)
        _ = try await capture.execute(picture, now: today)
        #expect(try await repository.fetchEvents().map(\.kind) == [.first(id: Self.picture.id)])
    }

    @Test("Given a retired first, or a child not in the family, when capturing, then it is refused and nothing is stored")
    func retiredOrUnknownChild() async throws {
        await #expect(throws: MomentError.notOffered(Self.retired.id)) {
            let retired = CaptureMomentRequest(firstID: Self.retired.id, childID: child, date: today)
            return try await capture.execute(retired, now: today)
        }
        await #expect(throws: MomentError.unknownChild) {
            try await capture.execute(request(child: UUID()), now: today)
        }
        #expect(try await repository.fetchEvents().isEmpty)
    }

    @Test("Given a captured moment, when moving it to the day before the birth, then it is refused; to the birth day, moved")
    func anEditFollowsTheFirstsDay() async throws {
        let moment = try await captured()

        await #expect(throws: MomentError.dateBeforeBirth) {
            try await update.execute(
                momentID: moment.id, happenedOn: birth.addingTimeInterval(-1), note: nil, photos: [], now: today
            )
        }
        #expect(try await repository.fetchEvents() == [moment])

        try await update.execute(momentID: moment.id, happenedOn: birth, note: nil, photos: [], now: today)
        #expect(try await repository.fetchEvents().map(\.date) == [birth])
    }

    @Test("Given a moment already dated before the birth, when editing its note or moving it later, then kept; earlier, refused")
    func anEditKeepsAnEarlierDay() async throws {
        let early = birth.addingTimeInterval(-10 * 86_400)
        let moment = ProgressEvent(kind: .first(id: firstID), childID: child, date: early)
        try await repository.add(moment)

        try await update.execute(momentID: moment.id, happenedOn: early, note: "νωρίς", photos: [], now: today)

        let stored = try #require(try await repository.fetchEvents().first)
        #expect(stored.date == early)
        #expect(stored.note == "νωρίς")
        await #expect(throws: MomentError.dateBeforeBirth) {
            try await update.execute(
                momentID: moment.id, happenedOn: early.addingTimeInterval(-86_400), note: nil, photos: [], now: today
            )
        }
        try await update.execute(
            momentID: moment.id, happenedOn: early.addingTimeInterval(86_400), note: nil, photos: [], now: today
        )
        #expect(try await repository.fetchEvents().map(\.date) == [early.addingTimeInterval(86_400)])
    }

    @Test("Given a captured moment, when moving it to a day after today, then it is refused and stays as it was")
    func anEditRefusesAFutureDay() async throws {
        let moment = try await captured(note: "πριν")

        await #expect(throws: MomentError.dateInFuture) {
            try await update.execute(
                momentID: moment.id, happenedOn: today.addingTimeInterval(86_400), note: "μετά", photos: [], now: today
            )
        }

        #expect(try await repository.fetchEvents() == [moment])
    }
}
