import Application
import Domain
import Foundation

// Format 1 of a copy of the saga (ADR-0057 §3, §4). FROZEN once released: a copy written by any version that wrote
// format 1 is read with exactly these types. A change to what a copy holds is `SagaCopyV2DTO`, not an edit here.
//
// Every value is spelled out by a switch, never by a Swift `rawValue` alone, so renaming a case in the Domain can't
// change the file. A value format 1 doesn't know throws `.damaged`: an older app never restores less than the file holds
// without saying so.

/// Only what every format's manifest has, read first so a newer format is refused before anything else is.
struct SagaCopyManifestHead: Decodable {
    let kind: String
    let formatVersion: Int
}

struct SagaCopyManifestV1: Codable, Equatable {
    let kind: String
    let formatVersion: Int
    /// Seconds since 1 January 2001, as `Date` holds them, so a date comes back exactly.
    let madeAt: Double
    /// How many `photos/` entries follow `saga.json`.
    let photoCount: Int
}

struct SagaCopySagaV1: Codable, Equatable {
    struct Hero: Codable, Equatable {
        let classID: String
        let skinTone: String
        let hair: String
        let hairColor: String
        let beard: String
        let glasses: String
        let hasPartner: Bool
    }

    struct Child: Codable, Equatable {
        let id: UUID
        let name: String
        /// `yyyy-MM-dd`; absent while the child is not born yet.
        let birthDay: String?
        let gender: String
        let skinTone: String
    }

    struct Entry: Codable, Equatable {
        let id: UUID
        /// `quest`, `boss` or `first`.
        let kind: String
        /// As stored, known to this version or not (ADR-0057 §5).
        let contentID: String
        let childID: UUID
        /// Seconds since 1 January 2001.
        let date: Double
        let note: String?
        /// Photo ids, in the dad's order; each has its `photos/<id>.jpg` entry.
        let photos: [String]
    }

    struct WardrobeChoice: Codable, Equatable {
        let skill: String
        /// `hidden` or `item`; automatic is not written.
        let choice: String
        let itemID: String?
    }

    struct Standing: Codable, Equatable {
        let titleID: String?
        /// Absent for a saga from before titles whose gear was never frozen, which is not the same as none (ADR-0055 §4).
        let gearIDs: [String]?
        let seenTitleID: String?
    }

    let hero: Hero
    let children: [Child]
    let entries: [Entry]
    let wardrobe: [WardrobeChoice]
    let standing: Standing
    let answeredOccasionIDs: [String]
}

struct SagaCopyChecksumsV1: Codable, Equatable {
    /// SHA-256 of each entry before `checksums.json`, in lowercase hex, by path.
    let sha256: [String: String]
}

// MARK: - Mapping

extension SagaCopyManifestV1 {
    init(copy: SagaCopy) {
        self.init(
            kind: SagaCopyFormat.kind,
            formatVersion: 1,
            madeAt: copy.madeAt.timeIntervalSinceReferenceDate,
            photoCount: copy.saga.photoIDs.count
        )
    }
}

extension SagaCopySagaV1 {
    init(copy: SagaCopy) {
        let profile = copy.saga.profile
        hero = Hero(
            classID: profile.heroClassID,
            skinTone: SagaCopyNamesV1.name(of: profile.dadSkinTone),
            hair: SagaCopyNamesV1.name(of: profile.dadAppearance.hair),
            hairColor: SagaCopyNamesV1.name(of: profile.dadAppearance.hairColor),
            beard: SagaCopyNamesV1.name(of: profile.dadAppearance.beard),
            glasses: SagaCopyNamesV1.name(of: profile.dadAppearance.glasses),
            hasPartner: profile.hasPartner
        )
        children = profile.children.map { child in
            Child(
                id: child.id, name: child.name, birthDay: child.birthDay.map(SagaCopyNamesV1.name(of:)),
                gender: SagaCopyNamesV1.name(of: child.gender), skinTone: SagaCopyNamesV1.name(of: child.skinTone)
            )
        }
        entries = copy.saga.events.map { event in
            let (kind, contentID) = SagaCopyNamesV1.names(of: event.kind)
            return Entry(
                id: event.id, kind: kind, contentID: contentID, childID: event.childID,
                date: event.date.timeIntervalSinceReferenceDate, note: event.note, photos: event.photoIDs
            )
        }
        wardrobe = Skill.allCases.compactMap { skill in
            switch copy.saga.outfit.choice(for: skill) {
            case .automatic: nil
            case .hidden: WardrobeChoice(skill: SagaCopyNamesV1.name(of: skill), choice: "hidden", itemID: nil)
            case .item(let id): WardrobeChoice(skill: SagaCopyNamesV1.name(of: skill), choice: "item", itemID: id)
            }
        }
        let kept = copy.saga.kept
        standing = Standing(titleID: kept.titleID, gearIDs: kept.gearIDs, seenTitleID: kept.seenTitleID)
        answeredOccasionIDs = copy.answeredOccasionIDs.sorted()
    }

    /// Throws `.damaged` for any value format 1 doesn't have.
    func toDomain(madeAt: Date) throws(SagaCopyError) -> SagaCopy {
        let tone = try SagaCopyNamesV1.skinTone(hero.skinTone)
        let look = DadAppearance(
            hair: try SagaCopyNamesV1.hair(hero.hair), hairColor: try SagaCopyNamesV1.hairColor(hero.hairColor),
            beard: try SagaCopyNamesV1.beard(hero.beard), glasses: try SagaCopyNamesV1.glasses(hero.glasses)
        )
        var family: [Domain.Child] = []
        for child in children {
            family.append(Domain.Child(
                id: child.id, name: child.name, birthDay: try child.birthDay.map { day throws(SagaCopyError) in
                    try SagaCopyNamesV1.day(day)
                },
                gender: try SagaCopyNamesV1.gender(child.gender), skinTone: try SagaCopyNamesV1.skinTone(child.skinTone)
            ))
        }
        var events: [ProgressEvent] = []
        for entry in entries {
            events.append(ProgressEvent(
                id: entry.id, kind: try SagaCopyNamesV1.kind(entry.kind, contentID: entry.contentID), childID: entry.childID,
                date: Date(timeIntervalSinceReferenceDate: entry.date), note: entry.note, photoIDs: entry.photos
            ))
        }
        var outfit = Outfit()
        for choice in wardrobe {
            let skill = try SagaCopyNamesV1.skill(choice.skill)
            guard outfit.choices[skill] == nil else { throw .damaged }
            switch (choice.choice, choice.itemID) {
            case ("hidden", nil): outfit.choices[skill] = .hidden
            case ("item", let id?): outfit.choices[skill] = .item(id)
            default: throw .damaged
            }
        }
        let saga = StoredSaga(
            profile: PlayerProfile(
                children: family, heroClassID: hero.classID, dadSkinTone: tone, dadAppearance: look,
                hasPartner: hero.hasPartner
            ),
            events: events,
            outfit: outfit,
            kept: KeptStanding(titleID: standing.titleID, gearIDs: standing.gearIDs, seenTitleID: standing.seenTitleID)
        )
        return SagaCopy(saga: saga, answeredOccasionIDs: Set(answeredOccasionIDs), madeAt: madeAt)
    }
}

/// Format 1's names for the Domain's values, both ways. Each switch is exhaustive, so a new case doesn't compile until
/// it has a name, and the format-coverage test then asks for a new format version.
enum SagaCopyNamesV1 {
    static func name(of tone: SkinTone) -> String {
        switch tone {
        case .light: "light"
        case .mediumLight: "mediumLight"
        case .medium: "medium"
        case .mediumDark: "mediumDark"
        case .dark: "dark"
        }
    }

    static func skinTone(_ name: String) throws(SagaCopyError) -> SkinTone {
        switch name {
        case "light": .light
        case "mediumLight": .mediumLight
        case "medium": .medium
        case "mediumDark": .mediumDark
        case "dark": .dark
        default: throw .damaged
        }
    }

    static func name(of gender: Gender) -> String {
        switch gender {
        case .boy: "boy"
        case .girl: "girl"
        }
    }

    static func gender(_ name: String) throws(SagaCopyError) -> Gender {
        switch name {
        case "boy": .boy
        case "girl": .girl
        default: throw .damaged
        }
    }

    static func name(of hair: DadAppearance.Hair) -> String {
        switch hair {
        case .short: "short"
        case .curly: "curly"
        case .long: "long"
        case .shaved: "shaved"
        }
    }

    static func hair(_ name: String) throws(SagaCopyError) -> DadAppearance.Hair {
        switch name {
        case "short": .short
        case "curly": .curly
        case "long": .long
        case "shaved": .shaved
        default: throw .damaged
        }
    }

    static func name(of color: DadAppearance.HairColor) -> String {
        switch color {
        case .black: "black"
        case .brown: "brown"
        case .blond: "blond"
        case .red: "red"
        case .grey: "grey"
        }
    }

    static func hairColor(_ name: String) throws(SagaCopyError) -> DadAppearance.HairColor {
        switch name {
        case "black": .black
        case "brown": .brown
        case "blond": .blond
        case "red": .red
        case "grey": .grey
        default: throw .damaged
        }
    }

    static func name(of beard: DadAppearance.Beard) -> String {
        switch beard {
        case .none: "none"
        case .short: "short"
        case .full: "full"
        }
    }

    static func beard(_ name: String) throws(SagaCopyError) -> DadAppearance.Beard {
        switch name {
        case "none": DadAppearance.Beard.none
        case "short": .short
        case "full": .full
        default: throw .damaged
        }
    }

    static func name(of glasses: DadAppearance.Glasses) -> String {
        switch glasses {
        case .none: "none"
        case .round: "round"
        }
    }

    static func glasses(_ name: String) throws(SagaCopyError) -> DadAppearance.Glasses {
        switch name {
        case "none": DadAppearance.Glasses.none
        case "round": .round
        default: throw .damaged
        }
    }

    static func name(of skill: Skill) -> String {
        switch skill {
        case .care: "care"
        case .play: "play"
        case .patience: "patience"
        case .resilience: "resilience"
        }
    }

    static func skill(_ name: String) throws(SagaCopyError) -> Skill {
        switch name {
        case "care": .care
        case "play": .play
        case "patience": .patience
        case "resilience": .resilience
        default: throw .damaged
        }
    }

    static func names(of kind: ProgressEvent.Kind) -> (kind: String, contentID: String) {
        switch kind {
        case .quest(let id): ("quest", id)
        case .boss(let id): ("boss", id)
        case .first(let id): ("first", id)
        }
    }

    static func kind(_ name: String, contentID: String) throws(SagaCopyError) -> ProgressEvent.Kind {
        switch name {
        case "quest": .quest(id: contentID)
        case "boss": .boss(id: contentID)
        case "first": .first(id: contentID)
        default: throw .damaged
        }
    }

    static func name(of day: CalendarDay) -> String {
        String(format: "%04d-%02d-%02d", day.year, day.month, day.day)
    }

    /// Only `yyyy-MM-dd` naming a day the Gregorian calendar has.
    static func day(_ name: String) throws(SagaCopyError) -> CalendarDay {
        let parts = name.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy(\.isASCII) && $0.allSatisfy(\.isNumber) }),
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              let calendarDay = CalendarDay(year: year, month: month, day: day) else { throw .damaged }
        return calendarDay
    }
}
