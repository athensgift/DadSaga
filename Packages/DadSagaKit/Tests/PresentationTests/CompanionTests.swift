import Domain
import Presentation
import Testing

@Suite("CompanionStage")
struct CompanionStageTests {
    @Test(
        "Given an age in months, when choosing how the child is drawn, then the stage follows the age bands",
        arguments: [
            (0, CompanionStage.baby), (11, .baby), (12, .toddler), (35, .toddler),
            (36, .preschooler), (71, .preschooler), (72, .kid), (150, .kid)
        ]
    )
    func stages(months: Int, expected: CompanionStage) {
        #expect(CompanionStage(age: .months(months)) == expected)
    }

    @Test("Given a child not born yet, when choosing how they are drawn, then it is the mark for a child on the way")
    func onTheWay() {
        #expect(CompanionStage(age: .beforeBirth) == .onTheWay)
    }
}
