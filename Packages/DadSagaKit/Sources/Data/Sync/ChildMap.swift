import Foundation

/// Which of this iPhone's children is which of the family's, from a join or a follow (ADR-0065 §2, §4): each mapped
/// child's entries move to the family's child, and their own row goes. A child mapped to their own id is the same
/// child already.
///
/// It travels in `saga`, so it is written as one JSON object of UUID strings, this iPhone's child to the family's.
struct ChildMap: Hashable, Sendable, Codable {
    /// This iPhone's child id, to the family's.
    var familyIDs: [UUID: UUID]

    init(familyIDs: [UUID: UUID] = [:]) {
        self.familyIDs = familyIDs
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        var familyIDs: [UUID: UUID] = [:]
        for (own, family) in try container.decode([String: String].self) {
            guard let own = UUID(uuidString: own), let family = UUID(uuidString: family) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "A child id is not a UUID")
            }
            familyIDs[own] = family
        }
        self.familyIDs = familyIDs
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Dictionary(uniqueKeysWithValues: familyIDs.map { ($0.key.uuidString, $0.value.uuidString) }))
    }

    /// The children that become another child: one mapped to their own id is the same child already.
    var moves: [UUID: UUID] { familyIDs.filter { $0.key != $0.value } }

    /// Whether an id is both a child that moves and a family's child: entries would move twice. A join never makes
    /// one.
    var isChained: Bool { !Set(moves.keys).isDisjoint(with: moves.values) }

    /// As it is kept in `Sync.store` and travels in `saga`: the same bytes for the same map.
    var json: Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(self)
    }

    /// Nil for anything that is not a whole map: never half of one.
    init?(json: Data) {
        guard let map = try? JSONDecoder().decode(ChildMap.self, from: json) else { return nil }
        self = map
    }

    /// The id of a film occasion once its child is the family's: an occasion's id starts with its child's
    /// (`<childID>/birthday/1`), and the answers to offers are kept by it (ADR-0065 §1). Any other id is as it was.
    func occasionID(_ id: String) -> String {
        guard let slash = id.firstIndex(of: "/"), let own = UUID(uuidString: String(id[..<slash])),
              let family = familyIDs[own] else { return id }
        return family.uuidString + id[slash...]
    }
}
