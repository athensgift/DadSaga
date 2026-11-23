import Application
import Domain
import Foundation
import Testing

/// An Undo leaves the dad's title, its gear and what the store keeps exactly as if the card had never been recorded,
/// in every order of steps home's screens allow (ADR-0055 §3). Each sequence runs twice through the real use cases:
/// as it happened, and again with the undone cards never recorded.
@Suite("Undo, in every order the screens allow")
struct UndoSequencesTests {
    enum Step: CaseIterable {
        /// A quest or boss: its Undo takes the bar.
        case card
        /// A first, in its sheet, which holds its Undo.
        case cardInSheet
        case undoBar, undoSheet, closeSheet, barExpires, closeTitleCard
        /// A deletion, from the timeline or the moment editor.
        case deleteOldest
    }

    /// What the screens hold while the steps run: whose Undo is on the bar and in the sheet, and the entries, oldest
    /// first, each named by the step that recorded it.
    struct Screens {
        var bar: Int?
        var sheet: Int?
        var entries: [Int] = []
        var undone: Set<Int> = []

        /// Whether the screens allow the step. The sheet is modal: under it, only the bar's time runs.
        func allows(_ step: Step) -> Bool {
            switch step {
            case .card, .cardInSheet, .closeTitleCard: sheet == nil
            case .undoBar: bar != nil && sheet == nil
            case .undoSheet, .closeSheet: sheet != nil
            case .barExpires: bar != nil
            case .deleteOldest: sheet == nil && !entries.isEmpty
            }
        }

        /// The screens after a step, or `nil` when they don't allow it.
        func after(_ step: Step, at index: Int) -> Screens? {
            guard allows(step) else { return nil }
            var next = self
            switch step {
            case .card:
                next.bar = index
                next.entries.append(index)
            case .cardInSheet:
                next.sheet = index
                next.entries.append(index)
            case .undoBar:
                next.take(bar)
                next.bar = nil
            case .undoSheet:
                next.take(sheet)
                next.sheet = nil
            case .closeSheet:
                next.sheet = nil
            case .barExpires:
                next.bar = nil
            case .closeTitleCard:
                break
            case .deleteOldest:
                next.entries.removeFirst()
                // A deletion ends the bar's Undo: on the timeline home has left the screen, and the moment editor
                // ends it itself.
                next.bar = nil
            }
            return next
        }

        private mutating func take(_ entry: Int?) {
            guard let entry else { return }
            entries.removeAll { $0 == entry }
            undone.insert(entry)
        }
    }

    /// Every sequence of up to `length` steps the screens allow.
    static func sequences(upTo length: Int, from screens: Screens = Screens(), steps: [Step] = []) -> [[Step]] {
        guard steps.count < length else { return [steps] }
        return [steps] + Step.allCases.flatMap { step -> [[Step]] in
            guard let next = screens.after(step, at: steps.count) else { return [] }
            return sequences(upTo: length, from: next, steps: steps + [step])
        }
    }

    static let text = Stub.text
    /// Titles close together, so a few cards of 20 or 40 XP cross several.
    static let catalog = ContentCatalog(
        worlds: Stub.catalog.worlds,
        quests: [("q20", 20), ("q40", 40)].map { id, xp in
            Quest(id: id, worldID: "w1", title: text, description: text, skill: .care, xp: xp, minAgeMonths: 0)
        },
        bosses: [],
        firsts: [],
        titles: [(0, 0), (1, 20), (2, 60), (3, 100), (5, 140)].enumerated().map { order, needs in
            DadTitle(id: "t\(order)", order: order, minCards: needs.0, minXP: needs.1, name: text)
        }
    )

    struct Outcome: Equatable {
        let titleID: String?
        let keptTitleID: String?
        let entries: Int
    }

    /// One saga in memory, through the real use cases.
    struct Saga {
        let content = StubContentRepository(result: .success(UndoSequencesTests.catalog))
        let progress = SpyProgressRepository()
        let standing = InMemoryStanding()
        let photos = SpyPhotoStore()

        func record(questID: String) async throws -> UUID? {
            try await DefaultCompleteQuestUseCase(
                contentRepository: content, progressRepository: progress, profileRepository: TheDad(), photoStore: photos
            )
            .execute(questID: questID, childID: UUID(), on: .now, journal: .empty).eventID
        }

        func delete(_ eventID: UUID) async throws {
            try await DefaultDeleteEventUseCase(
                contentRepository: content, progressRepository: progress, standingRepository: standing, photoStore: photos
            )
            .execute(eventID: eventID)
        }

        /// Undoes the entry, and checks the two rules of the closed card on the way.
        func undo(_ eventID: UUID, in steps: [Step]) async throws {
            let had = try await stand()
            let held = try await DefaultUndoRecordUseCase(
                contentRepository: content, progressRepository: progress, standingRepository: standing, photoStore: photos
            )
            .execute(undoing: eventID)
            let has = try await stand()
            // The Undo says what he still holds.
            #expect(held == has.title, "\(steps)")
            // A card he closed never comes back for a title he still holds.
            #expect(had.news != nil || has.news == nil, "\(steps)")
            // And the card of a title the Undo took is no longer closed, so it comes again with the title.
            let seen = await standing.kept.seenTitleID.flatMap(UndoSequencesTests.catalog.title(id:))
            #expect((seen?.order ?? 0) <= (has.title?.order ?? 0), "\(steps)")
        }

        func closeTitleCard() async throws {
            if let news = try await stand().news { try await standing.markSeen(titleID: news.title.id) }
        }

        func stand() async throws -> DadStanding {
            let catalog = UndoSequencesTests.catalog
            let progress = DadProgress(events: try await progress.fetchEvents(), catalog: catalog)
            return DadStanding(progress: progress, catalog: catalog, kept: await standing.kept)
        }

        func outcome() async throws -> Outcome {
            Outcome(
                titleID: try await stand().title?.id,
                keptTitleID: await standing.kept.titleID,
                entries: try await progress.fetchEvents().count
            )
        }
    }

    /// Runs the steps through the real use cases.
    /// - Parameter neverRecorded: the cards left out, with their Undos: the same history had he never tapped them.
    func run(_ steps: [Step], neverRecorded: Set<Int>? = nil) async throws -> Outcome {
        let saga = Saga()
        var screens = Screens()
        var events: [Int: UUID] = [:]
        for (index, step) in steps.enumerated() {
            let before = screens
            screens = try #require(before.after(step, at: index))
            switch step {
            case .card, .cardInSheet:
                if neverRecorded?.contains(index) == true { continue }
                events[index] = try await saga.record(questID: step == .card ? "q20" : "q40")
            case .undoBar, .undoSheet:
                if neverRecorded != nil { continue }
                let entry = try #require(step == .undoBar ? before.bar : before.sheet)
                try await saga.undo(try #require(events[entry]), in: steps)
            case .closeTitleCard:
                try await saga.closeTitleCard()
            case .deleteOldest:
                let oldest = try #require(before.entries.first)
                try await saga.delete(try #require(events[oldest]))
            case .closeSheet, .barExpires:
                break
            }
        }
        return try await saga.outcome()
    }

    @Test("Given any steps the screens allow, when cards are undone, then the title is as if they were never recorded")
    func undoIsAsIfNeverRecorded() async throws {
        let all = Self.sequences(upTo: 7)
        #expect(all.count > 15000)
        for steps in all {
            var screens = Screens()
            for (index, step) in steps.enumerated() {
                screens = try #require(screens.after(step, at: index))
            }
            guard !screens.undone.isEmpty else { continue }

            let happened = try await run(steps)
            let neverTapped = try await run(steps, neverRecorded: screens.undone)

            #expect(happened == neverTapped, "\(steps)")
        }
    }
}
