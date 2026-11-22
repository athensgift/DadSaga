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

    /// Updates or deletes the skill's one row, or inserts it (ADR-0065 §5). Synchronous inside the actor between the
    /// fetch, the write and the read.
    func setChoice(_ choice: OutfitChoice, for skill: Skill) async throws -> Outfit {
        let raw = skill.rawValue
        try modelContext.saveAllOrNothing {
            var descriptor = FetchDescriptor<OutfitRecord>(predicate: #Predicate { $0.skill == raw })
            descriptor.fetchLimit = 1
            let record = try modelContext.fetch(descriptor).first
            switch (record, OutfitCoding.encode(choice)) {
            case (let record?, let encoded?): record.choice = encoded
            case (nil, let encoded?): modelContext.insert(OutfitRecord(skill: raw, choice: encoded))
            case (let record?, nil): modelContext.delete(record)
            case (nil, nil): break
            }
        }
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
