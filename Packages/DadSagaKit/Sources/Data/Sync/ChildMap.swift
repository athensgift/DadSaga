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

    /// The id of a film occasion once its child is the family's: an occasion's id starts with its child's
    /// (`<childID>/birthday/1`), and the answers to offers are kept by it (ADR-0065 §1). Any other id is as it was.
    func occasionID(_ id: String) -> String {
        guard let slash = id.firstIndex(of: "/"), let own = UUID(uuidString: String(id[..<slash])),
              let family = familyIDs[own] else { return id }
        return family.uuidString + id[slash...]
    }
}
