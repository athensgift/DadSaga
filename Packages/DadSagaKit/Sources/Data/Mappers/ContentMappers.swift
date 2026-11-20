import Application
import Domain
import Foundation

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
            minAgeMonths: minAgeMonths,
            tip: tip?.toDomain(),
            isEvergreen: evergreen ?? false
        )
    }
}

extension QuestTipDTO {
    func toDomain() -> QuestTip {
        QuestTip(title: title.toDomain(), steps: steps.map { $0.toDomain() }, isMedical: medical ?? false)
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
            minAgeMonths: minAgeMonths,
            requiresSibling: requiresSibling ?? false
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

extension HeroClassDTO {
    func toDomain() -> HeroClass {
        HeroClass(id: id, order: order, title: title.toDomain(), tagline: tagline.toDomain(), look: look)
    }
}

extension GearItemDTO {
    func toDomain() throws -> GearItem {
        GearItem(id: id, skill: try QuestDTO.skill(skill, itemID: id), minXP: minXP, look: look, title: title.toDomain())
    }
}

extension AppearanceOptionDTO {
    func toDomain() throws -> DadAppearanceOption {
        guard let part = DadAppearance.Part(rawValue: part) else {
            throw ContentDataError.unknownAppearanceOption(part: self.part, id: id)
        }
        return DadAppearanceOption(part: part, id: id, title: title.toDomain())
    }
}

extension SoundtrackDTO {
    func toDomain(audioURL: URL) throws -> Soundtrack {
        guard let licence = SoundtrackLicence(rawValue: licence) else {
            throw ContentDataError.unknownLicence(itemID: id, licence: self.licence)
        }
        return Soundtrack(
            id: id, title: title.toDomain(), mood: mood.toDomain(), artist: artist, licence: licence, audioURL: audioURL
        )
    }
}
