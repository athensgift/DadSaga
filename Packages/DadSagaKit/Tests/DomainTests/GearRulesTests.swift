import Domain
import Testing

@Suite("GearRules")
struct GearRulesTests {
    let gear = [
        GearItem(id: "cloth", skill: .care, minXP: 50, look: "burpCloth", title: Fixtures.text),
        GearItem(id: "gold", skill: .care, minXP: 200, look: "burpClothGold", title: Fixtures.text),
        GearItem(id: "mug", skill: .patience, minXP: 50, look: "mug", title: Fixtures.text)
    ]

    @Test("Given no skill XP, when equipping, then the hero carries nothing")
    func nothingYet() {
        #expect(GearRules.equipped(gear, skillXP: [:]).isEmpty)
    }

    @Test("Given XP past both care thresholds and one patience threshold, when equipping, then the best of each is carried")
    func bestPerSkill() {
        let equipped = GearRules.equipped(gear, skillXP: [.care: 250, .patience: 50, .play: 500])
        #expect(equipped.map(\.id) == ["gold", "mug"])
    }

    @Test("Given XP just below a threshold, when equipping, then that item is not carried")
    func belowThreshold() {
        #expect(GearRules.equipped(gear, skillXP: [.care: 49]).isEmpty)
    }

    @Test("Given a change that crosses a threshold, when comparing, then only the new item is reported")
    func newlyEarned() {
        let new = GearRules.newlyEarned(gear, before: [.care: 60, .patience: 40], after: [.care: 80, .patience: 60])
        #expect(new.map(\.id) == ["mug"])
    }

    @Test("Given XP past both care tiers, when listing earned items, then both come, lowest first")
    func earned() {
        #expect(GearRules.earned(gear, skillXP: [.care: 250, .patience: 50]).map(\.id) == ["cloth", "gold", "mug"])
    }

    @Test("Given wardrobe choices, when equipping, then a chosen item, nothing, or the best are worn per slot")
    func outfitChoices() {
        let xp: [Skill: Int] = [.care: 250, .patience: 50]
        let outfit = Outfit(choices: [.care: .item("cloth"), .patience: .hidden])
        #expect(GearRules.equipped(gear, skillXP: xp, outfit: outfit).map(\.id) == ["cloth"])
        #expect(GearRules.equipped(gear, skillXP: xp, outfit: Outfit(choices: [.care: .automatic])).map(\.id) == ["gold", "mug"])
    }

    @Test("Given a chosen item that is not earned, when equipping, then the best earned item is worn instead")
    func chosenButNotEarned() {
        let outfit = Outfit(choices: [.care: .item("gold")])
        #expect(GearRules.equipped(gear, skillXP: [.care: 60], outfit: outfit).map(\.id) == ["cloth"])
    }
}
