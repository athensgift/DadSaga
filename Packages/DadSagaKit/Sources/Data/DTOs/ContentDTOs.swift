// Wire format of the bundled JSON. Kept separate from Domain entities so the file format can change
// without touching business code.

struct LocalizedTextDTO: Decodable, Sendable {
    let el: String
    let en: String
}

struct WorldDTO: Decodable, Sendable {
    let id: String
    let order: Int
    let title: LocalizedTextDTO
    let tagline: LocalizedTextDTO
    let minAgeMonths: Int
    let maxAgeMonths: Int?
}

struct QuestDTO: Decodable, Sendable {
    let id: String
    let worldID: String
    let title: LocalizedTextDTO
    let description: LocalizedTextDTO
    let skill: String
    let xp: Int
    let minAgeMonths: Int
    var tip: QuestTipDTO?
    var evergreen: Bool?
}

struct QuestTipDTO: Decodable, Sendable {
    let title: LocalizedTextDTO
    let steps: [LocalizedTextDTO]
    let medical: Bool?
}

struct BossFightDTO: Decodable, Sendable {
    let id: String
    let worldID: String
    let title: LocalizedTextDTO
    let intro: LocalizedTextDTO
    let guide: [LocalizedTextDTO]
    let badge: LocalizedTextDTO
    let skill: String
    let xp: Int
    let minAgeMonths: Int
    var requiresSibling: Bool?
}

struct FirstMomentDTO: Decodable, Sendable {
    let id: String
    let order: Int
    let emoji: String
    let title: LocalizedTextDTO
    let xp: Int
    let companionTrait: String?
}

struct HeroClassDTO: Decodable, Sendable {
    let id: String
    let order: Int
    let title: LocalizedTextDTO
    let tagline: LocalizedTextDTO
    let look: String
}

struct GearItemDTO: Decodable, Sendable {
    let id: String
    let skill: String
    let minXP: Int
    let look: String
    let title: LocalizedTextDTO
}

/// The name of one of the dad's look options (ADR-0044 §3). `id` is unique within its `part` only.
struct AppearanceOptionDTO: Decodable, Sendable {
    let part: String
    let id: String
    let title: LocalizedTextDTO
}

struct SoundtrackDTO: Decodable, Sendable {
    let id: String
    /// A file bundled next to the JSON, e.g. `saga-theme.m4a`. Names must be unique: resources are flattened.
    let file: String
    /// In Greek and English like all content (ADR-0005, ADR-0046 §1); the artist is one name.
    let title: LocalizedTextDTO
    /// How it sounds, shown under the title on the film sheet.
    let mood: LocalizedTextDTO
    let artist: String
    let licence: String
    /// Where it came from: a tool in this repository, or the page its licence was taken from.
    let source: String
}
