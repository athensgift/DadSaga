import Application
import Domain
import Foundation
import SwiftData

/// `OutfitRepository` backed by SwiftData. Created through `LocalStore`.
@ModelActor
actor SwiftDataOutfitRepository: OutfitRepository {
    func fetchOutfit() async throws -> Outfit {
        try currentOutfit()
    }

    /// Synchronous inside the actor between the delete, the insert and the read.
    func setChoice(_ choice: OutfitChoice, for skill: Skill) async throws -> Outfit {
        let raw = skill.rawValue
        try modelContext.delete(model: OutfitRecord.self, where: #Predicate { $0.skill == raw })
        if let encoded = OutfitCoding.encode(choice) {
            modelContext.insert(OutfitRecord(skill: raw, choice: encoded))
        }
        try modelContext.save()
        return try currentOutfit()
    }

    private func currentOutfit() throws -> Outfit {
        var outfit = Outfit()
        for record in try modelContext.fetch(FetchDescriptor<OutfitRecord>()) {
            guard let skill = Skill(rawValue: record.skill), let choice = OutfitCoding.decode(record.choice) else { continue }
            outfit.choices[skill] = choice
        }
        return outfit
    }

    func deleteAll() async throws {
        try modelContext.delete(model: OutfitRecord.self)
        try modelContext.save()
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
