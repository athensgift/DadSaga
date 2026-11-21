import Application
import Domain

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
                  tagline: LocalizedText(el: "τ", en: "t"), span: .months(min: 0, max: nil))
        ],
        quests: [
            Quest(id: "q1", worldID: "w1", title: LocalizedText(el: "Αποστολή", en: "Quest"),
                  description: LocalizedText(el: "δ", en: "d"), skill: .care, xp: 20, minAgeMonths: 0,
                  formerIDs: ["q1-before"])
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
