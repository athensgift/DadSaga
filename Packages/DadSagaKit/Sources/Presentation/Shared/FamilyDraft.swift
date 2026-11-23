import Domain
import Foundation
import Localization

public enum GenderChoice: CaseIterable, Hashable, Sendable {
    case boy, girl
}

public enum SkinToneChoice: CaseIterable, Hashable, Sendable {
    case light, mediumLight, medium, mediumDark, dark
}

/// One child as it is being entered or edited.
public struct ChildDraft: Identifiable, Equatable, Sendable {
    /// Kept from the stored child when editing, so their progress stays linked.
    public let id: UUID
    public var name: String
    /// Off while the switch "Not born yet" is on (ADR-0053 §1): then no day is kept, and date, gender and skin tone
    /// aren't asked.
    public var isBorn: Bool
    /// The day the dad picked (ADR-0048 §2), or the day the picker shows when he unticks "Not born yet": today for a
    /// child not born yet. It is kept as a day, so a time zone change while the screen is open moves nothing; only the
    /// picker converts, through `pickerDate(in:)` and `pickBirthDate(_:in:)`.
    public var birthDay: CalendarDay
    public var gender: GenderChoice
    public var skinTone: SkinToneChoice

    public var hasName: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The moment the date picker shows: the start of the birth day in `timeZone`, the zone the picker draws in.
    public func pickerDate(in timeZone: TimeZone) -> Date {
        birthDay.start(in: timeZone)
    }

    /// The dad picked `date` in a picker drawn in `timeZone`: only its day is kept.
    public mutating func pickBirthDate(_ date: Date, in timeZone: TimeZone) {
        birthDay = CalendarDay(date, in: timeZone)
    }

    public init(
        id: UUID = UUID(),
        name: String = "",
        birthDay: CalendarDay,
        isBorn: Bool = true,
        gender: GenderChoice = .boy,
        skinTone: SkinToneChoice = .mediumLight
    ) {
        self.id = id
        self.name = name
        self.isBorn = isBorn
        self.birthDay = birthDay
        self.gender = gender
        self.skinTone = skinTone
    }
}

/// The family being entered (onboarding) or edited (family screen): 1 to 4 children, the dad's skin tone and whether
/// he raises them with a partner.
public struct FamilyDraft: Equatable, Sendable {
    public var children: [ChildDraft]
    public var dadSkinTone: SkinToneChoice
    /// "I have a partner" (ADR-0053 §4): on unless he turns it off.
    public var hasPartner: Bool

    /// "Child 1", "Child 2": the place of `id` in the family, counted from one.
    public func number(of id: UUID) -> Int {
        (children.firstIndex { $0.id == id } ?? children.count) + 1
    }

    public var canAddChild: Bool { children.count < PlayerProfile.maxChildren }
    public var canRemoveChild: Bool { children.count > 1 }
    /// Every child has a name.
    public var isComplete: Bool { !children.isEmpty && children.allSatisfy(\.hasName) }

    public init(children: [ChildDraft], dadSkinTone: SkinToneChoice = .mediumLight, hasPartner: Bool = true) {
        self.children = children
        self.dadSkinTone = dadSkinTone
        self.hasPartner = hasPartner
    }

    /// New children start with the newest sibling's skin tone, which is usually right.
    public mutating func addChild(birthDay: CalendarDay) {
        guard canAddChild else { return }
        children.append(ChildDraft(birthDay: birthDay, skinTone: children.last?.skinTone ?? dadSkinTone))
    }

    public mutating func removeChild(id: UUID) {
        guard canRemoveChild else { return }
        children.removeAll { $0.id == id }
    }
}

/// Text for the child editor, shared by onboarding and the family screen.
public struct ChildEditorLabels: Equatable, Sendable {
    public let childTitle: String
    public let namePlaceholder: String
    /// The name's placeholder while "Not born yet" is on.
    public let unbornNamePlaceholder: String
    /// The switch under the name.
    public let notBornLabel: String
    public let birthDateLabel: String
    public let genderLabel: String
    public let boy: String
    public let girl: String
    public let skinToneLabel: String
    /// Accessibility names of the tones, in `SkinToneChoice.allCases` order.
    public let skinToneNames: [String]
    public let removeTitle: String
    public let addChildTitle: String

    static func make(locale: Locale) -> ChildEditorLabels {
        let strings = Strings(locale: locale)
        return ChildEditorLabels(
            childTitle: strings.text("Child"),
            namePlaceholder: strings.text("Name"),
            unbornNamePlaceholder: strings.text("Name or nickname"),
            notBornLabel: strings.text("Not born yet"),
            birthDateLabel: strings.text("Date of birth"),
            genderLabel: strings.text("Gender"),
            boy: strings.text("Boy"),
            girl: strings.text("Girl"),
            skinToneLabel: strings.text("Skin tone"),
            skinToneNames: [
                strings.text("Light"),
                strings.text("Medium light"),
                strings.text("Medium"),
                strings.text("Medium dark"),
                strings.text("Dark")
            ],
            removeTitle: strings.text("Remove child"),
            addChildTitle: strings.text("Add a child")
        )
    }
}

// MARK: - Mapping to and from the Domain

extension GenderChoice {
    init(_ gender: Gender) {
        switch gender {
        case .boy: self = .boy
        case .girl: self = .girl
        }
    }

    var domain: Gender {
        switch self {
        case .boy: .boy
        case .girl: .girl
        }
    }
}

extension SkinToneChoice {
    init(_ tone: SkinTone) {
        switch tone {
        case .light: self = .light
        case .mediumLight: self = .mediumLight
        case .medium: self = .medium
        case .mediumDark: self = .mediumDark
        case .dark: self = .dark
        }
    }

    var domain: SkinTone {
        switch self {
        case .light: .light
        case .mediumLight: .mediumLight
        case .medium: .medium
        case .mediumDark: .mediumDark
        case .dark: .dark
        }
    }
}

extension ChildDraft {
    /// A child not born yet gets `today` for the picker, shown once he unticks "Not born yet".
    init(_ child: Child, today: CalendarDay) {
        self.init(
            id: child.id,
            name: child.name,
            birthDay: child.birthDay ?? today,
            isBorn: child.isBorn,
            gender: GenderChoice(child.gender),
            skinTone: SkinToneChoice(child.skinTone)
        )
    }

    var child: Child {
        Child(
            id: id,
            name: name,
            birthDay: isBorn ? birthDay : nil,
            gender: gender.domain,
            skinTone: skinTone.domain
        )
    }
}

extension FamilyDraft {
    init(_ profile: PlayerProfile, today: CalendarDay) {
        self.init(
            children: profile.children.map { ChildDraft($0, today: today) },
            dadSkinTone: SkinToneChoice(profile.dadSkinTone),
            hasPartner: profile.hasPartner
        )
    }
}

/// The partner switch and its line, the same in onboarding and "My family" (ADR-0053 §4).
public struct PartnerRowLabels: Equatable, Sendable {
    public let title: String
    public let line: String

    static func make(locale: Locale) -> PartnerRowLabels {
        let strings = Strings(locale: locale)
        return PartnerRowLabels(
            title: strings.text("I have a partner"),
            line: strings.text("Shows the cards for the two of you.")
        )
    }
}
