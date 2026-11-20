import Foundation

/// How the dad himself looks: his hair, its colour, his beard and his glasses (ADR-0044). Free to change at any time;
/// never earned, locked or celebrated (ADR-0006).
public struct DadAppearance: Hashable, Sendable {
    public enum Hair: String, CaseIterable, Hashable, Sendable { case short, curly, long, shaved }
    public enum HairColor: String, CaseIterable, Hashable, Sendable { case black, brown, blond, red, grey }
    public enum Beard: String, CaseIterable, Hashable, Sendable { case none, short, full }
    public enum Glasses: String, CaseIterable, Hashable, Sendable { case none, round }

    /// One of the four choices, named as the content names it.
    public enum Part: String, CaseIterable, Hashable, Sendable { case hair, hairColor, beard, glasses }

    public var hair: Hair
    public var hairColor: HairColor
    public var beard: Beard
    public var glasses: Glasses

    public init(hair: Hair = .short, hairColor: HairColor = .brown, beard: Beard = .full, glasses: Glasses = .none) {
        self.hair = hair
        self.hairColor = hairColor
        self.beard = beard
        self.glasses = glasses
    }

    /// How every dad was drawn before he could choose: short hair, a full beard, no glasses, and hair brown for the
    /// three lighter skin tones and black for the two deeper ones.
    public static func standard(for skinTone: SkinTone) -> DadAppearance {
        switch skinTone {
        case .light, .mediumLight, .medium: DadAppearance(hairColor: .brown)
        case .mediumDark, .dark: DadAppearance(hairColor: .black)
        }
    }

    /// This look on a dad whose skin tone changes from `old` to `new`: a hair colour that is still the old tone's
    /// standard one follows the tone, as it did before the dad could choose; one he chose stays (ADR-0044 §1).
    public func changingSkinTone(from old: SkinTone, to new: SkinTone) -> DadAppearance {
        guard hairColor == Self.standard(for: old).hairColor else { return self }
        var look = self
        look.hairColor = Self.standard(for: new).hairColor
        return look
    }

    /// Every option of `part`, in the order the Domain knows them. The content must list exactly these.
    public static func optionIDs(for part: Part) -> [String] {
        switch part {
        case .hair: Hair.allCases.map(\.rawValue)
        case .hairColor: HairColor.allCases.map(\.rawValue)
        case .beard: Beard.allCases.map(\.rawValue)
        case .glasses: Glasses.allCases.map(\.rawValue)
        }
    }

    /// The option chosen for `part`.
    public func optionID(for part: Part) -> String {
        switch part {
        case .hair: hair.rawValue
        case .hairColor: hairColor.rawValue
        case .beard: beard.rawValue
        case .glasses: glasses.rawValue
        }
    }

    /// This look with option `id` for `part`, or `nil` when `part` has no such option.
    public func choosing(_ id: String, for part: Part) -> DadAppearance? {
        var look = self
        switch part {
        case .hair: guard let value = Hair(rawValue: id) else { return nil }; look.hair = value
        case .hairColor: guard let value = HairColor(rawValue: id) else { return nil }; look.hairColor = value
        case .beard: guard let value = Beard(rawValue: id) else { return nil }; look.beard = value
        case .glasses: guard let value = Glasses(rawValue: id) else { return nil }; look.glasses = value
        }
        return look
    }
}

/// The name of one look option, from the content.
public struct DadAppearanceOption: Hashable, Sendable {
    public let part: DadAppearance.Part
    public let id: String
    public let title: LocalizedText

    public init(part: DadAppearance.Part, id: String, title: LocalizedText) {
        self.part = part
        self.id = id
        self.title = title
    }
}
