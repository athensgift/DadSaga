import Application
import Domain
import Foundation
import Presentation
import Testing

@MainActor
@Suite("HomeViewModel, legendary moments")
struct HomeMomentsTests {
    let progress = FakeProgress()

    func makeSUT(profile: PlayerProfile?) -> HomeViewModel {
        makeHomeViewModel(profile: profile, progress: progress)
    }

    @Test("Given no moments, when appearing, then the section is empty and counts all firsts")
    func emptyMoments() async {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()
        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(content.moments.title == "Θρυλικές στιγμές")
        #expect(content.moments.progress == "0")
        #expect(content.moments.cards.isEmpty)
        #expect(!content.moments.isComplete)
    }

    @Test("Given first steps, when capturing them, then a gold card shows, the child stands and the celebration says so")
    func capturesMoment() async {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()

        sut.startCapture()
        #expect(sut.momentCapture?.options.map(\.title) == ["Βήματα"])
        #expect(sut.momentCapture?.title == "Νίκος")
        await sut.saveMoment(firstID: "f1", date: HeroStub.today, note: "Τρία βήματα!", photo: .replace(Data([1, 2])))

        #expect(sut.momentCapture == nil)
        #expect(sut.celebration?.momentText == "👣 Βήματα")
        #expect(sut.celebration?.xpText == "+30 XP")
        #expect(sut.celebration?.highlight == .moment)
        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(content.moments.cards.map(\.title) == ["👣 Βήματα"])
        #expect(content.moments.cards.first?.subtitle.hasSuffix(" · Τρία βήματα!") == true)
        #expect(content.moments.isComplete)
        #expect(content.companions.first?.traits == [.walks])
        let photoID = content.moments.cards.first?.photoID
        #expect(photoID != nil)
        #expect(await sut.photoData(id: photoID ?? "", maxPixelSize: 192) == Data([1, 2]))

        sut.startCapture()
        #expect(sut.momentCapture?.options.isEmpty == true)
    }

    @Test("Given a captured moment, when editing its note and removing the photo, then the card changes without a celebration")
    func editsMoment() async throws {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()
        sut.startCapture()
        await sut.saveMoment(firstID: "f1", date: HeroStub.today, note: "πριν", photo: .replace(Data([1])))
        sut.celebrationFinished()
        guard case .loaded(let before) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        let card = try #require(before.moments.cards.first)

        sut.editMoment(id: card.id)
        #expect(sut.momentCapture?.editing?.note == "πριν")
        #expect(sut.momentCapture?.editing?.photoIDs == [card.photoID].compactMap(\.self))
        #expect(sut.momentCapture?.options.map(\.id) == ["f1"])
        await sut.saveMoment(firstID: "f1", date: HeroStub.today, note: "μετά", photo: .remove)

        #expect(sut.momentCapture == nil)
        #expect(sut.celebration == nil)
        guard case .loaded(let after) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(after.moments.cards.first?.id == card.id)
        #expect(after.moments.cards.first?.subtitle.hasSuffix(" · μετά") == true)
        #expect(after.moments.cards.first?.photoID == nil)
        #expect(after.xpLine == before.xpLine)
    }

    @Test("Given a captured moment, when deleting it, then the card, its XP and the child's trait are gone")
    func deletesMoment() async throws {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()
        sut.startCapture()
        await sut.saveMoment(firstID: "f1", date: HeroStub.today, note: "")
        guard case .loaded(let before) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        sut.editMoment(id: try #require(before.moments.cards.first?.id))

        await sut.deleteMoment()

        #expect(sut.momentCapture == nil)
        guard case .loaded(let after) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        #expect(after.moments.cards.isEmpty)
        #expect(after.xpLine == "0 / 100 XP")
        #expect(after.companions.first?.traits.isEmpty == true)
    }

    @Test("Given a moment with three photos, when replacing its photo, then only the cover changes and the rest stay")
    func replacingKeepsTheOtherPhotos() async throws {
        await progress.seedMoment(photos: [Data([1]), Data([2]), Data([3])])
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()
        let id = try #require(loadedMoments(sut)?.cards.first?.id)
        sut.editMoment(id: id)
        #expect(sut.momentCapture?.editing?.photoIDs == ["photo-1", "photo-2", "photo-3"])
        #expect(loadedMoments(sut)?.cards.first?.photoID == "photo-1")

        await sut.saveMoment(firstID: "f1", date: HeroStub.today, note: "", photo: .replace(Data([4])))
        sut.editMoment(id: id)
        #expect(sut.momentCapture?.editing?.photoIDs == ["photo-4", "photo-2", "photo-3"])

        await sut.saveMoment(firstID: "f1", date: HeroStub.today, note: "", photo: .remove)
        sut.editMoment(id: id)
        #expect(sut.momentCapture?.editing?.photoIDs == ["photo-2", "photo-3"])

        await sut.saveMoment(firstID: "f1", date: HeroStub.today, note: "", photo: .keep)
        sut.editMoment(id: id)
        #expect(sut.momentCapture?.editing?.photoIDs == ["photo-2", "photo-3"])
    }

    private func loadedMoments(_ sut: HomeViewModel) -> MomentsSection? {
        guard case .loaded(let content) = sut.state else { return nil }
        return content.moments
    }

    @Test("Given saving fails, when editing a moment, then the sheet stays open with an error")
    func editFailure() async throws {
        let sut = makeSUT(profile: HeroStub.profile)
        await sut.onAppear()
        sut.startCapture()
        await sut.saveMoment(firstID: "f1", date: HeroStub.today, note: "")
        guard case .loaded(let content) = sut.state else {
            Issue.record("Expected loaded state, got \(sut.state)")
            return
        }
        sut.editMoment(id: try #require(content.moments.cards.first?.id))
        await progress.failNext()

        await sut.saveMoment(firstID: "f1", date: HeroStub.today, note: "x")

        #expect(sut.momentCapture != nil)
        #expect(sut.errorMessage == "Δεν αποθηκεύτηκε. Δοκίμασε ξανά.")
    }
}
