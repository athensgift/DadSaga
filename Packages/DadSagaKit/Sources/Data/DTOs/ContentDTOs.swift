// Wire format of the bundled JSON. Kept separate from Domain entities so the file format can change
// without touching business code.

struct LocalizedTextDTO: Decodable, Sendable {
    let el: String
    let en: String
}

struct WorldDTO: Decodable, Sendable {
    let id: String
    /// Ids it had before a rename (ADR-0048 §5). Once shipped, an id is never dropped.
    var formerIDs: [String]?
    let order: Int
    let title: LocalizedTextDTO
    let tagline: LocalizedTextDTO
    /// `true` for the world before birth, which has no ages (ADR-0053 §2).
    var beforeBirth: Bool?
    var minAgeMonths: Int?
    var maxAgeMonths: Int?
}

struct QuestDTO: Decodable, Sendable {
    let id: String
    /// Ids it had before a rename (ADR-0048 §5). Once shipped, an id is never dropped.
    var formerIDs: [String]?
    let worldID: String
    let title: LocalizedTextDTO
    let description: LocalizedTextDTO
    let skill: String
    let xp: Int
    let minAgeMonths: Int
    var tip: QuestTipDTO?
    var evergreen: Bool?
    /// Who the card is for, as `Audience` raw values (ADR-0053 §4); every one must hold.
    var onlyFor: [String]?
    /// A shipped card never offered again (ADR-0053 §6).
    var retired: Bool?
}

struct QuestTipDTO: Decodable, Sendable {
    let title: LocalizedTextDTO
    let steps: [LocalizedTextDTO]
    let medical: Bool?
}

struct BossFightDTO: Decodable, Sendable {
    let id: String
    /// Ids it had before a rename (ADR-0048 §5). Once shipped, an id is never dropped.
    var formerIDs: [String]?
    let worldID: String
    let title: LocalizedTextDTO
    let intro: LocalizedTextDTO
    let guide: [LocalizedTextDTO]
    let badge: LocalizedTextDTO
    let skill: String
    let xp: Int
    let minAgeMonths: Int
    /// Who the card is for, as `Audience` raw values (ADR-0053 §4); every one must hold.
    var onlyFor: [String]?
    /// For when life changes: home keeps it in a closed row (ADR-0053 §5).
    var situational: Bool?
    /// Also shown in every later world (ADR-0053 §5).
    var evergreen: Bool?
}

struct FirstMomentDTO: Decodable, Sendable {
    let id: String
    /// Ids it had before a rename (ADR-0048 §5). Once shipped, an id is never dropped.
    var formerIDs: [String]?
    let order: Int
    let emoji: String
    let title: LocalizedTextDTO
    let xp: Int
    let companionTrait: String?
    /// A first before the birth (ADR-0053 §3).
    var beforeBirth: Bool?
    /// A shipped first never offered again (ADR-0053 §6).
    var retired: Bool?
}

struct HeroClassDTO: Decodable, Sendable {
    let id: String
    /// Ids it had before a rename (ADR-0048 §5). Once shipped, an id is never dropped.
    var formerIDs: [String]?
    let order: Int
    let title: LocalizedTextDTO
    let tagline: LocalizedTextDTO
    let look: String
}

struct GearItemDTO: Decodable, Sendable {
    let id: String
    /// Ids it had before a rename (ADR-0048 §5). Once shipped, an id is never dropped.
    var formerIDs: [String]?
    let skill: String
    let look: String
    let title: LocalizedTextDTO
}

/// One of the dad's titles (ADR-0055 §2).
struct DadTitleDTO: Decodable, Sendable {
    let id: String
    var formerIDs: [String]?
    let order: Int
    let minCards: Int
    let minXP: Int
    let gear: [String]
    let name: LocalizedTextDTO
}

/// How fast one skill's mark grows (ADR-0059 §2). No text: skill names are UI strings (ADR-0027).
struct SkillCurveDTO: Decodable, Sendable {
    let skill: String
    let halfGrownXP: Int
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
