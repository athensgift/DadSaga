import Application
import Domain
import Foundation
import SwiftData

/// SwiftData storage shape of one wardrobe choice. Slots that are automatic have no record.
@Model
final class OutfitRecord {
    var skill: String
    /// "hidden" or "item:<gear id>".
    var choice: String

    init(skill: String, choice: String) {
        self.skill = skill
        self.choice = choice
    }
}

/// `OutfitRepository` backed by SwiftData. Created through `LocalStore`.
@ModelActor
actor SwiftDataOutfitRepository: OutfitRepository {
    func fetchOutfit() async throws -> Outfit {
        var outfit = Outfit()
        for record in try modelContext.fetch(FetchDescriptor<OutfitRecord>()) {
            guard let skill = Skill(rawValue: record.skill), let choice = OutfitCoding.decode(record.choice) else { continue }
            outfit.choices[skill] = choice
        }
        return outfit
    }

    func save(_ outfit: Outfit) async throws {
        try modelContext.delete(model: OutfitRecord.self)
        for (skill, choice) in outfit.choices {
            guard let encoded = OutfitCoding.encode(choice) else { continue }
            modelContext.insert(OutfitRecord(skill: skill.rawValue, choice: encoded))
        }
        try modelContext.save()
    }

    func deleteAll() async throws {
        try modelContext.delete(model: OutfitRecord.self)
        try modelContext.save()
    }
}

actor InMemoryOutfitRepository: OutfitRepository {
    private var outfit = Outfit()

    func fetchOutfit() async throws -> Outfit {
        outfit
    }

    func save(_ outfit: Outfit) async throws {
        self.outfit = outfit
    }

    func deleteAll() async throws {
        outfit = Outfit()
    }
}

enum OutfitCoding {
    private static let itemPrefix = "item:"

    /// `nil` for automatic, which is not stored.
    static func encode(_ choice: OutfitChoice) -> String? {
        switch choice {
        case .automatic: nil
        case .hidden: "hidden"
        case .item(let id): itemPrefix + id
        }
    }

    /// `nil` for anything this version does not understand, which then counts as automatic.
    static func decode(_ raw: String) -> OutfitChoice? {
        if raw == "hidden" { return .hidden }
        guard raw.hasPrefix(itemPrefix) else { return nil }
        return .item(String(raw.dropFirst(itemPrefix.count)))
    }
}
