import Domain

extension LocalizedTextDTO {
    func toDomain() -> LocalizedText {
        LocalizedText(el: el, en: en)
    }
}

extension WorldDTO {
    func toDomain() -> World {
        World(
            id: id,
            order: order,
            title: title.toDomain(),
            tagline: tagline.toDomain(),
            minAgeMonths: minAgeMonths,
            maxAgeMonths: maxAgeMonths
        )
    }
}

extension QuestDTO {
    func toDomain() throws -> Quest {
        Quest(
            id: id,
            worldID: worldID,
            title: title.toDomain(),
            description: description.toDomain(),
            skill: try Self.skill(skill, itemID: id),
            xp: xp,
            minAgeMonths: minAgeMonths
        )
    }
}

extension BossFightDTO {
    func toDomain() throws -> BossFight {
        BossFight(
            id: id,
            worldID: worldID,
            title: title.toDomain(),
            intro: intro.toDomain(),
            guide: guide.map { $0.toDomain() },
            badge: badge.toDomain(),
            skill: try QuestDTO.skill(skill, itemID: id),
            xp: xp,
            minAgeMonths: minAgeMonths
        )
    }
}

extension FirstMomentDTO {
    func toDomain() -> FirstMoment {
        FirstMoment(
            id: id,
            order: order,
            emoji: emoji,
            title: title.toDomain(),
            xp: xp,
            companionTrait: companionTrait
        )
    }
}

extension QuestDTO {
    static func skill(_ raw: String, itemID: String) throws -> Skill {
        guard let skill = Skill(rawValue: raw) else {
            throw ContentDataError.unknownSkill(itemID: itemID, skill: raw)
        }
        return skill
    }
}
