import Domain
import Testing

@Suite("GearRules")
struct GearRulesTests {
    let gear = [
        GearItem(id: "cloth", skill: .care, look: "burpCloth", title: Fixtures.text),
        GearItem(id: "gold", skill: .care, look: "burpClothGold", title: Fixtures.text),
        GearItem(id: "mug", skill: .patience, look: "mug", title: Fixtures.text),
        GearItem(id: "new", skill: .play, look: "duck", title: Fixtures.text)
    ]

    @Test("Given nothing earned, when equipping, then the hero carries nothing")
    func nothingYet() {
        #expect(GearRules.equipped([]).isEmpty)
    }

    @Test("Given two care items and a mug, when equipping, then the best of each slot is carried")
    func bestPerSlot() {
        #expect(GearRules.equipped(Array(gear.prefix(3))).map(\.id) == ["gold", "mug"])
    }

    @Test("Given wardrobe choices, when equipping, then a chosen item, nothing, or the best are worn per slot")
    func outfitChoices() {
        let earned = Array(gear.prefix(3))
        let outfit = Outfit(choices: [.care: .item("cloth"), .patience: .hidden])
        #expect(GearRules.equipped(earned, outfit: outfit).map(\.id) == ["cloth"])
        #expect(GearRules.equipped(earned, outfit: Outfit(choices: [.care: .automatic])).map(\.id) == ["gold", "mug"])
    }

    @Test("Given a chosen item that is not earned, when equipping, then the best earned item is worn instead")
    func chosenButNotEarned() {
        let outfit = Outfit(choices: [.care: .item("gold")])
        #expect(GearRules.equipped([gear[0]], outfit: outfit).map(\.id) == ["cloth"])
    }
}
