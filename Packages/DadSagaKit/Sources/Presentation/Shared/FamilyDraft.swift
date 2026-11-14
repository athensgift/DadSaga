import Domain
import Foundation

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
    public var birthDate: Date
    public var gender: GenderChoice
    public var skinTone: SkinToneChoice

    public var hasName: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public init(
        id: UUID = UUID(),
        name: String = "",
        birthDate: Date,
        gender: GenderChoice = .boy,
        skinTone: SkinToneChoice = .mediumLight
    ) {
        self.id = id
        self.name = name
        self.birthDate = birthDate
        self.gender = gender
        self.skinTone = skinTone
    }
}

/// The family being entered (onboarding) or edited (family screen): 1 to 4 children and the dad's skin tone.
public struct FamilyDraft: Equatable, Sendable {
    public var children: [ChildDraft]
    public var dadSkinTone: SkinToneChoice

    public var canAddChild: Bool { children.count < PlayerProfile.maxChildren }
    public var canRemoveChild: Bool { children.count > 1 }
    /// Every child has a name.
    public var isComplete: Bool { !children.isEmpty && children.allSatisfy(\.hasName) }

    public init(children: [ChildDraft], dadSkinTone: SkinToneChoice = .mediumLight) {
        self.children = children
        self.dadSkinTone = dadSkinTone
    }

    /// New children start with the newest sibling's skin tone, which is usually right.
    public mutating func addChild(birthDate: Date) {
        guard canAddChild else { return }
        children.append(ChildDraft(birthDate: birthDate, skinTone: children.last?.skinTone ?? dadSkinTone))
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
        let text = { (el: String, en: String) in LocalizedText(el: el, en: en).resolved(for: locale) }
        return ChildEditorLabels(
            childTitle: text("Παιδί", "Child"),
            namePlaceholder: text("Όνομα", "Name"),
            birthDateLabel: text("Ημερομηνία γέννησης", "Date of birth"),
            genderLabel: text("Φύλο", "Gender"),
            boy: text("Αγόρι", "Boy"),
            girl: text("Κορίτσι", "Girl"),
            skinToneLabel: text("Απόχρωση", "Skin tone"),
            skinToneNames: [
                text("Ανοιχτή", "Light"),
                text("Ανοιχτή μεσαία", "Medium light"),
                text("Μεσαία", "Medium"),
                text("Σκούρα μεσαία", "Medium dark"),
                text("Σκούρα", "Dark")
            ],
            removeTitle: text("Αφαίρεση παιδιού", "Remove child"),
            addChildTitle: text("Πρόσθεσε παιδί", "Add a child")
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
    init(_ child: Child) {
        self.init(
            id: child.id,
            name: child.name,
            birthDate: child.birthDate,
            gender: GenderChoice(child.gender),
            skinTone: SkinToneChoice(child.skinTone)
        )
    }

    var child: Child {
        Child(id: id, name: name, birthDate: birthDate, gender: gender.domain, skinTone: skinTone.domain)
    }
}

extension FamilyDraft {
    init(_ profile: PlayerProfile) {
        self.init(children: profile.children.map(ChildDraft.init), dadSkinTone: SkinToneChoice(profile.dadSkinTone))
    }
}
