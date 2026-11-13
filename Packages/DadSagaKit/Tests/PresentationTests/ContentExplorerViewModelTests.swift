import Application
import Domain
import Foundation
import Presentation
import Testing

@MainActor
@Suite("ContentExplorerViewModel")
struct ContentExplorerViewModelTests {
    @Test("Given a new view model, when created, then state is loading")
    func initialState() {
        let sut = ContentExplorerViewModel(loadCatalog: StubLoadCatalog(result: .success(Stub.catalog)))
        #expect(sut.state == .loading)
    }

    @Test("Given a Greek locale and content, when appearing, then cards are mapped with Greek text and bosses first")
    func loadedGreek() async throws {
        let sut = ContentExplorerViewModel(
            loadCatalog: StubLoadCatalog(result: .success(Stub.catalog)),
            locale: Locale(identifier: "el_GR")
        )

        await sut.onAppear()

        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(content.level == 1)
        #expect(content.firstsTitle == "Θρυλικές στιγμές")
        let world = try #require(content.worlds.first)
        #expect(world.title == "Κόσμος")
        #expect(world.cards.map(\.kind) == [.boss, .quest])
        #expect(world.cards.last?.badge == "+20 XP · Φροντίδα")
        #expect(content.firsts.first?.title == "👣 Βήματα")
        #expect(content.firsts.first?.kind == .legendary)
    }

    @Test("Given an English locale, when appearing, then text is English")
    func loadedEnglish() async throws {
        let sut = ContentExplorerViewModel(
            loadCatalog: StubLoadCatalog(result: .success(Stub.catalog)),
            locale: Locale(identifier: "en_US")
        )

        await sut.onAppear()

        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(content.worlds.first?.title == "World")
        #expect(content.worlds.first?.cards.last?.badge == "+20 XP · Care")
    }

    @Test("Given a failing use case, when appearing, then state is failed with a user-facing message")
    func failure() async {
        let sut = ContentExplorerViewModel(
            loadCatalog: StubLoadCatalog(result: .failure(StubError.boom)),
            locale: Locale(identifier: "el_GR")
        )

        await sut.onAppear()

        #expect(sut.state == .failed(message: "Το περιεχόμενο δεν φόρτωσε."))
    }
}

enum StubError: Error { case boom }

struct StubLoadCatalog: LoadContentCatalogUseCase {
    let result: Result<ContentCatalog, StubError>

    func execute() async throws -> ContentCatalog {
        try result.get()
    }
}

enum Stub {
    static let catalog = ContentCatalog(
        worlds: [
            World(id: "w1", order: 1, title: LocalizedText(el: "Κόσμος", en: "World"),
                  tagline: LocalizedText(el: "τ", en: "t"), minAgeMonths: 0, maxAgeMonths: nil)
        ],
        quests: [
            Quest(id: "q1", worldID: "w1", title: LocalizedText(el: "Αποστολή", en: "Quest"),
                  description: LocalizedText(el: "δ", en: "d"), skill: .care, xp: 20, minAgeMonths: 0)
        ],
        bosses: [
            BossFight(id: "b1", worldID: "w1", title: LocalizedText(el: "Αφεντικό", en: "Boss"),
                      intro: LocalizedText(el: "ι", en: "i"), guide: [], badge: LocalizedText(el: "β", en: "b"),
                      skill: .care, xp: 100, minAgeMonths: 0)
        ],
        firsts: [
            FirstMoment(id: "f1", order: 1, emoji: "👣", title: LocalizedText(el: "Βήματα", en: "Steps"),
                        xp: 30, companionTrait: "walk")
        ]
    )
}
