import Foundation

/// The hero fields an edit on "Your hero" sets; `nil` leaves the stored value, even one this version can't name
/// (ADR-0065 §1). Never the children, the kept title or the id. Spell out `DadAppearance.Beard.none` and
/// `DadAppearance.Glasses.none`: a bare `.none` is `Optional.none`, which leaves the part as stored.
public struct HeroEdit: Hashable, Sendable {
    public var heroClassID: String?
    public var dadSkinTone: SkinTone?
    public var hair: DadAppearance.Hair?
    public var hairColor: DadAppearance.HairColor?
    public var beard: DadAppearance.Beard?
    public var glasses: DadAppearance.Glasses?

    public init(
        heroClassID: String? = nil,
        dadSkinTone: SkinTone? = nil,
        hair: DadAppearance.Hair? = nil,
        hairColor: DadAppearance.HairColor? = nil,
        beard: DadAppearance.Beard? = nil,
        glasses: DadAppearance.Glasses? = nil
    ) {
        self.heroClassID = heroClassID
        self.dadSkinTone = dadSkinTone
        self.hair = hair
        self.hairColor = hairColor
        self.beard = beard
        self.glasses = glasses
    }

    public var isEmpty: Bool {
        heroClassID == nil && dadSkinTone == nil && hair == nil && hairColor == nil && beard == nil && glasses == nil
    }

    /// `profile` with this edit's fields set on it.
    public func applied(to profile: PlayerProfile) -> PlayerProfile {
        var result = profile
        if let heroClassID { result.heroClassID = heroClassID }
        if let dadSkinTone { result.dadSkinTone = dadSkinTone }
        if let hair { result.dadAppearance.hair = hair }
        if let hairColor { result.dadAppearance.hairColor = hairColor }
        if let beard { result.dadAppearance.beard = beard }
        if let glasses { result.dadAppearance.glasses = glasses }
        return result
    }
}
