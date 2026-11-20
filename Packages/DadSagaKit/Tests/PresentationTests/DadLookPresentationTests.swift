import Domain
import Foundation
import Presentation
import Testing

// The dad's look on the screens that draw him (ADR-0044 §7).

extension HomeViewModelTests {
    @Test("Given a dad with long red hair, no beard and glasses, when appearing, then home draws him that way")
    func drawsTheDadsLook() async throws {
        var profile = HeroStub.profile
        profile.dadAppearance = DadAppearance(hair: .long, hairColor: .red, beard: .none, glasses: .round)
        let sut = makeSUT(profile: profile)
        await sut.onAppear()
        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(content.heroAppearance.hair == .long)
        #expect(content.heroAppearance.hairColor == .red)
        #expect(content.heroAppearance.beard == .none)
        #expect(content.heroAppearance.glasses == .round)
    }
}

extension OnboardingViewModelTests {
    @Test("Given the hero step, when choosing the dark tone, then the heroes are drawn with black hair")
    func heroesFollowTheTone() {
        let sut = makeSUT()
        sut.family.dadSkinTone = .light
        #expect(sut.dadAppearance.hairColor == .brown)

        sut.family.dadSkinTone = .dark

        #expect(sut.dadAppearance.hairColor == .black)
        #expect(sut.dadAppearance.beard == .full)
    }
}
