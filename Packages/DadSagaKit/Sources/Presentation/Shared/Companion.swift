import Domain
import Foundation
import Localization

/// How old a child looks on screen.
public enum CompanionStage: CaseIterable, Sendable {
    /// Not born yet: a small mark beside the hero, not a child (ADR-0051 §2).
    case onTheWay
    case baby, toddler, preschooler, kid

    /// Before birth on the way, 0–11 months baby, 1–2 years toddler, 3–5 years preschooler, 6+ kid.
    public init(age: ChildAge) {
        guard let months = age.months else {
            self = .onTheWay
            return
        }
        switch months {
        case ..<12: self = .baby
        case ..<36: self = .toddler
        case ..<72: self = .preschooler
        default: self = .kid
        }
    }
}

/// A visible change on a child, earned by capturing a legendary moment.
public enum CompanionTrait: CaseIterable, Hashable, Sendable {
    case smile, tooth, walks, partyHat

    /// From the content's `companionTrait`; traits with no drawing (e.g. "crawl") give `nil`.
    init?(content: String) {
        switch content {
        case "smile", "laugh": self = .smile
        case "tooth": self = .tooth
        case "walk": self = .walks
        case "party-hat": self = .partyHat
        default: return nil
        }
    }
}

/// A child as drawn next to the dad.
public struct CompanionModel: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    /// What VoiceOver reads: the name, or "<name>, on the way" for a child not born yet.
    public let spokenName: String
    public let stage: CompanionStage
    public let gender: GenderChoice
    public let skin: SkinToneChoice
    public let traits: Set<CompanionTrait>
}

extension ChildDraft {
    /// The stage the child is drawn at on the day `date` falls on in `timeZone`.
    func stage(at date: Date, timeZone: TimeZone) -> CompanionStage {
        CompanionStage(age: child.age(on: CalendarDay(date, in: timeZone)))
    }
}

extension CompanionModel {
    /// The child as drawn on `day`.
    init(child: Child, on day: CalendarDay, traits: Set<CompanionTrait>, strings: Strings) {
        self.init(child: child, stage: CompanionStage(age: child.age(on: day)), traits: traits, strings: strings)
    }

    /// The child drawn at `stage`; VoiceOver reads "<name>, on the way" for the mark.
    init(child: Child, stage: CompanionStage, traits: Set<CompanionTrait>, strings: Strings) {
        self.init(
            id: child.id,
            name: child.name,
            spokenName: stage == .onTheWay ? strings.text("\(child.name), on the way") : child.name,
            stage: stage,
            gender: GenderChoice(child.gender),
            skin: SkinToneChoice(child.skinTone),
            traits: traits
        )
    }
}
