import Application
import Domain
import Foundation

extension LocalizedTextDTO {
    func toDomain() -> LocalizedText {
        LocalizedText(el: el, en: en)
    }
}

extension WorldDTO {
    /// A world is either before birth with no ages, or has a minimum age (ADR-0053 §7).
    func toDomain() throws -> World {
        let span: WorldSpan
        switch (beforeBirth ?? false, minAgeMonths, maxAgeMonths) {
        case (true, nil, nil): span = .beforeBirth
        case (false, let min?, let max): span = .months(min: min, max: max)
        default: throw ContentDataError.invalidWorldAges(worldID: id)
        }
        return World(
            id: id,
            order: order,
            title: title.toDomain(),
            tagline: tagline.toDomain(),
            span: span,
            formerIDs: formerIDs ?? []
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
            isEvergreen: evergreen ?? false,
            onlyFor: try Self.audiences(onlyFor, itemID: id),
            isRetired: retired ?? false,
            formerIDs: formerIDs ?? []
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
            onlyFor: try QuestDTO.audiences(onlyFor, itemID: id),
            isSituational: situational ?? false,
            isEvergreen: evergreen ?? false,
            formerIDs: formerIDs ?? []
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
            companionTrait: companionTrait,
            isBeforeBirth: beforeBirth ?? false,
            isRetired: retired ?? false,
            formerIDs: formerIDs ?? []
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

    /// Audience words are parsed like skills: an unknown one fails the load (ADR-0053 §4).
    static func audiences(_ raw: [String]?, itemID: String) throws -> Set<Audience> {
        Set(try (raw ?? []).map { word in
            guard let audience = Audience(rawValue: word) else {
                throw ContentDataError.unknownAudience(itemID: itemID, audience: word)
            }
            return audience
        })
    }
}

extension HeroClassDTO {
    func toDomain() -> HeroClass {
        HeroClass(
            id: id,
            order: order,
            title: title.toDomain(),
            tagline: tagline.toDomain(),
            look: look,
            formerIDs: formerIDs ?? []
        )
    }
}

extension GearItemDTO {
    func toDomain() throws -> GearItem {
        GearItem(
            id: id,
            skill: try QuestDTO.skill(skill, itemID: id),
            skillXPBeforeTitles: skillXPBeforeTitles,
            look: look,
            title: title.toDomain(),
            formerIDs: formerIDs ?? []
        )
    }
}

extension SkillCurveDTO {
    func toDomain() throws -> SkillCurve {
        SkillCurve(skill: try QuestDTO.skill(skill, itemID: "skills"), halfGrownXP: halfGrownXP)
    }
}

extension DadTitleDTO {
    func toDomain() -> DadTitle {
        DadTitle(
            id: id,
            order: order,
            minCards: minCards,
            minXP: minXP,
            gearIDs: gear,
            name: name.toDomain(),
            formerIDs: formerIDs ?? []
        )
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
