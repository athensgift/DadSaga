import Domain
import Foundation
import Testing

@Suite("DadAppearance")
struct DadAppearanceTests {
    @Test("Given each skin tone, when nothing is chosen, then the dad has short hair, a full beard and the tone's hair colour",
          arguments: [
              (SkinTone.light, DadAppearance.HairColor.brown), (.mediumLight, .brown), (.medium, .brown),
              (.mediumDark, .black), (.dark, .black)
          ])
    func standardLook(tone: SkinTone, hairColor: DadAppearance.HairColor) {
        #expect(DadAppearance.standard(for: tone)
            == DadAppearance(hair: .short, hairColor: hairColor, beard: .full, glasses: .none))
    }

    @Test("Given a look, when choosing no beard, then only the beard changes")
    func choosingChangesOnePart() {
        let look = DadAppearance(hair: .curly, hairColor: .red, beard: .full, glasses: .round)

        #expect(look.choosing("none", for: .beard)
            == DadAppearance(hair: .curly, hairColor: .red, beard: .none, glasses: .round))
        #expect(look.choosing("round", for: .glasses) == look)
    }

    @Test("Given the tone's own hair colour, when the tone changes, then the hair follows; a chosen colour stays")
    func hairFollowsToneUntilChosen() {
        let standard = DadAppearance.standard(for: .light)
        #expect(standard.changingSkinTone(from: .light, to: .dark).hairColor == .black)

        let red = DadAppearance(hairColor: .red)
        #expect(red.changingSkinTone(from: .light, to: .dark) == red)
    }

    @Test("Given an option a part doesn't have, when choosing it, then there is no look")
    func unknownOption() {
        #expect(DadAppearance().choosing("goatee", for: .beard) == nil)
        #expect(DadAppearance().choosing("curly", for: .beard) == nil)
    }

    @Test("Given each part, when listing its options, then the chosen one is always among them")
    func optionIDsCoverChoices() {
        let look = DadAppearance(hair: .long, hairColor: .grey, beard: .short, glasses: .round)
        for part in DadAppearance.Part.allCases {
            #expect(DadAppearance.optionIDs(for: part).contains(look.optionID(for: part)))
        }
        #expect(DadAppearance.optionIDs(for: .beard) == ["none", "short", "full"])
    }

    @Test("Given a profile made with only a dark skin tone, when reading its look, then it is the standard one for dark")
    func profileDefaultsToStandard() {
        let profile = PlayerProfile(children: [], heroClassID: "h1", dadSkinTone: .dark)
        #expect(profile.dadAppearance == .standard(for: .dark))
    }
}
