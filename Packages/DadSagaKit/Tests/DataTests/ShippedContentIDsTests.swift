@testable import Data
import Domain
import Foundation
import Testing

/// Every content id the app has shipped, with what it was worth then (ADR-0048 §5). Events, outfit choices and film
/// answers are stored by these ids, so none may ever go. Add each new card here in the same change; never remove one.
struct ShippedContentIDs: Decodable {
    struct Item: Decodable {
        let id: String
        var skill: String?
        var xp: Int?
        var minXP: Int?
    }

    let worlds: [Item]
    let heroes: [Item]
    let quests: [Item]
    let bosses: [Item]
    let firsts: [Item]
    let gear: [Item]
    /// Each title as it shipped: what it needed and the gear it brought (ADR-0055 §11).
    let titles: [Title]

    struct Title: Decodable {
        let id: String
        let minCards: Int
        let minXP: Int
        let gear: [String]
    }

    static func load() throws -> ShippedContentIDs {
        let url = URL(filePath: #filePath).deletingLastPathComponent().appending(path: "Fixtures/ShippedContentIDs.json")
        return try JSONDecoder().decode(ShippedContentIDs.self, from: Data(contentsOf: url))
    }
}

@Suite("Shipped content ids")
struct ShippedContentIDsTests {
    let shipped: ShippedContentIDs
    let catalog: ContentCatalog

    init() async throws {
        shipped = try ShippedContentIDs.load()
        catalog = try await BundledContentRepository().fetchCatalog()
    }

    /// One kind of content: the items shipped, and how to find today's item by any id it has had.
    struct Kind {
        let name: String
        let shipped: [ShippedContentIDs.Item]
        let find: (String) -> (any ContentItem)?
    }

    var kinds: [Kind] {
        [
            Kind(name: "worlds", shipped: shipped.worlds) { catalog.world(id: $0) },
            Kind(name: "heroes", shipped: shipped.heroes) { catalog.heroClass(id: $0) },
            Kind(name: "quests", shipped: shipped.quests) { catalog.quest(id: $0) },
            Kind(name: "bosses", shipped: shipped.bosses) { catalog.boss(id: $0) },
            Kind(name: "firsts", shipped: shipped.firsts) { catalog.first(id: $0) },
            Kind(name: "gear", shipped: shipped.gear) { catalog.gearItem(id: $0) },
            Kind(name: "titles", shipped: shipped.titles.map { ShippedContentIDs.Item(id: $0.id) }) { catalog.title(id: $0) }
        ]
    }

    var current: [(name: String, items: [any ContentItem])] {
        [
            ("worlds", catalog.worlds), ("heroes", catalog.heroClasses), ("quests", catalog.quests),
            ("bosses", catalog.bosses), ("firsts", catalog.firsts), ("gear", catalog.gear),
            ("titles", catalog.titles)
        ]
    }

    @Test("Given every id the app has shipped, when loading today's content, then each still finds an item of its kind")
    func everyShippedIDIsStillThere() {
        for kind in kinds {
            for item in kind.shipped {
                #expect(kind.find(item.id) != nil, "\(kind.name): \(item.id) is gone; keep it, or list it in formerIDs")
            }
        }
    }

    @Test("Given today's content, when checking each item, then its id is listed as shipped")
    func everyCurrentIDHasShipped() {
        for (kind, items) in zip(kinds, current) {
            let shippedIDs = Set(kind.shipped.map(\.id))
            for item in items.items {
                #expect(shippedIDs.contains(item.id), "\(items.name): add \(item.id) to ShippedContentIDs.json")
            }
        }
    }

    @Test("Given today's content, when checking its former ids, then each is an id that shipped as the same kind")
    func everyFormerIDHasShipped() {
        for (kind, items) in zip(kinds, current) {
            let shippedIDs = Set(kind.shipped.map(\.id))
            for item in items.items {
                for former in item.formerIDs {
                    #expect(shippedIDs.contains(former), "\(items.name): \(former) never shipped")
                }
            }
        }
    }

    @Test("Given today's content, when checking its retired cards, then each is one that shipped: an unshipped card is deleted")
    func everyRetiredCardHasShipped() {
        let quests = Set(shipped.quests.map(\.id))
        let firsts = Set(shipped.firsts.map(\.id))
        for quest in catalog.quests where quest.isRetired {
            #expect(quests.contains(quest.id), "\(quest.id) never shipped: delete it instead of retiring it")
        }
        for first in catalog.firsts where first.isRetired {
            #expect(firsts.contains(first.id), "\(first.id) never shipped: delete it instead of retiring it")
        }
    }

    @Test("Given what each shipped item was worth, when reading today's content, then nothing earned goes down or moves skill")
    func nothingEarnedGoesDown() {
        for item in shipped.quests {
            guard let quest = catalog.quest(id: item.id) else { continue }
            #expect(quest.skill.rawValue == item.skill, "\(item.id) moved skill")
            #expect(quest.xp >= item.xp ?? 0, "\(item.id) is worth less XP")
        }
        for item in shipped.bosses {
            guard let boss = catalog.boss(id: item.id) else { continue }
            #expect(boss.skill.rawValue == item.skill, "\(item.id) moved skill")
            #expect(boss.xp >= item.xp ?? 0, "\(item.id) is worth less XP")
        }
        for item in shipped.firsts {
            guard let first = catalog.first(id: item.id) else { continue }
            #expect(first.xp >= item.xp ?? 0, "\(item.id) is worth less XP")
        }
        for item in shipped.gear {
            guard let gear = catalog.gearItem(id: item.id) else { continue }
            #expect(gear.skill.rawValue == item.skill, "\(item.id) moved skill")
            // The rule from before titles only ever reads these, so a dad from then keeps his gear (ADR-0055 §4).
            #expect(
                gear.skillXPBeforeTitles == item.minXP,
                "\(item.id): its threshold from before titles must stay as it shipped, and only shipped items have one"
            )
        }
        for item in catalog.gear where !shipped.gear.contains(where: { gear in item.has(id: gear.id) }) {
            #expect(item.skillXPBeforeTitles == nil, "\(item.id) came after titles: no skill XP brings it")
        }
    }

    @Test("Given each shipped title, when reading today's titles, then none needs more and no item comes later")
    func titlesNeverAskForMore() {
        for shippedTitle in shipped.titles {
            guard let title = catalog.title(id: shippedTitle.id) else { continue }
            #expect(title.minCards <= shippedTitle.minCards, "\(shippedTitle.id) needs more cards")
            #expect(title.minXP <= shippedTitle.minXP, "\(shippedTitle.id) needs more XP")
            for gearID in shippedTitle.gear {
                let bringing = catalog.title(bringing: gearID)
                #expect((bringing?.order ?? .max) <= title.order, "\(gearID) moved to a later title")
            }
        }
    }
}
