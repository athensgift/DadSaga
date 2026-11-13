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
}

struct FirstMomentDTO: Decodable, Sendable {
    let id: String
    let order: Int
    let emoji: String
    let title: LocalizedTextDTO
    let xp: Int
    let companionTrait: String?
}
