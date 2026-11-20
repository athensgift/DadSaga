import Application
import Domain
import Foundation
import Testing
import WidgetPresentation

extension HomeWidgetContent {
    /// The tiles, or `nil` when this is a message, so a wrong state fails the expectations that follow.
    var tiles: Tiles? {
        if case .tiles(let tiles) = self { tiles } else { nil }
    }

    var message: String? {
        if case .message(let text) = self { text } else { nil }
    }
}

@Suite("HomeWidgetPresenter")
struct HomeWidgetPresenterTests {
    static let greek = Locale(identifier: "el_GR")
    static let english = Locale(identifier: "en_US")

    let child = Child(name: "Λένα", birthDate: Date(timeIntervalSince1970: 1_700_000_000))
    let quest = Quest(
        id: "q-w1-skin-to-skin",
        worldID: "w1",
        title: LocalizedText(el: "Ώρα αγκαλιάς", en: "Cuddle time"),
        description: LocalizedText(el: "x", en: "x"),
        skill: .care,
        xp: 15,
        minAgeMonths: 0
    )
    let moment = CapturedMoment(
        eventID: UUID(),
        first: FirstMoment(id: "f-steps", order: 1, emoji: "👣",
                           title: LocalizedText(el: "Πρώτα βήματα", en: "First steps"), xp: 30, companionTrait: nil),
        date: Date(timeIntervalSince1970: 1_780_000_000),
        note: "Ιδιωτικό σημείωμα",
        photoIDs: ["p1"]
    )

    func highlights(
        quest slot: WeeklyHighlights.QuestSlot? = nil,
        moment: CapturedMoment? = nil,
        photo: Data? = nil,
        childCount: Int = 1
    ) -> WeeklyHighlights {
        WeeklyHighlights(
            child: child,
            childCount: childCount,
            quest: slot ?? .suggested(quest, isDone: false),
            latestMoment: moment,
            momentPhoto: photo,
            validUntil: .distantFuture
        )
    }

    @Test("Given the weekly quest not done yet, when presenting, then it shows title and reward and says nothing more")
    func suggestedQuest() {
        let greek = HomeWidgetPresenter(locale: Self.greek).content(for: highlights(), showsPhoto: true)
        let english = HomeWidgetPresenter(locale: Self.english).content(for: highlights(), showsPhoto: true)

        #expect(greek.tiles?.quest.header == "Αποστολή της εβδομάδας")
        #expect(greek.tiles?.quest.title == "Ώρα αγκαλιάς")
        #expect(greek.tiles?.quest.reward?.hasPrefix("+15 XP · ") == true)
        #expect(greek.tiles?.quest.doneText == nil)
        #expect(greek.tiles?.quest.link == AppLink.quest(id: quest.id, childID: child.id).url)
        #expect(english.tiles?.quest.title == "Cuddle time")
        #expect(english.message == nil)
    }

    @Test("Given the weekly quest done this week, when presenting, then it says so calmly")
    func doneQuest() {
        let sut = HomeWidgetPresenter(locale: Self.english)
        let content = sut.content(for: highlights(quest: .suggested(quest, isDone: true)), showsPhoto: true)
        #expect(content.tiles?.quest.doneText == "✓ Done this week")
        let greek = HomeWidgetPresenter(locale: Self.greek)
        #expect(greek.content(for: highlights(quest: .suggested(quest, isDone: true)), showsPhoto: true)
            .tiles?.quest.doneText == "✓ Έγινε αυτή την εβδομάδα")
    }

    @Test("Given a child older than every world, when presenting, then adventures are coming and the tap opens home")
    func comingSoon() {
        let content = HomeWidgetPresenter(locale: Self.greek).content(for: highlights(quest: .comingSoon), showsPhoto: true)

        #expect(content.tiles?.quest.title == "Οι περιπέτειες για την ηλικία του παιδιού σου έρχονται σύντομα.")
        #expect(content.tiles?.quest.reward == nil)
        #expect(content.tiles?.quest.link == AppLink.child(child.id).url)
    }

    @Test("Given no moment yet, when presenting, then a neutral line shows and nothing is expected")
    func noMoment() {
        let english = HomeWidgetPresenter(locale: Self.english).content(for: highlights(), showsPhoto: true)
        let greek = HomeWidgetPresenter(locale: Self.greek).content(for: highlights(), showsPhoto: true)

        #expect(english.tiles?.moment.title == "Legendary moments you capture show up here.")
        #expect(greek.tiles?.moment.title == "Οι θρυλικές στιγμές που καταγράφεις θα εμφανίζονται εδώ.")
        #expect(english.tiles?.moment.date == nil)
        #expect(english.tiles?.moment.link == AppLink.child(child.id).url)
    }

    @Test("Given a moment with a photo, when presenting, then it shows the photo and never the note")
    func momentWithPhoto() throws {
        let photo = Data("jpeg".utf8)
        let content = HomeWidgetPresenter(locale: Self.greek)
            .content(for: highlights(moment: moment, photo: photo), showsPhoto: true)
        #expect(content.tiles != nil)

        #expect(content.tiles?.moment.emoji == "👣")
        #expect(content.tiles?.moment.title == "Πρώτα βήματα")
        #expect(content.tiles?.moment.photo == photo)
        #expect(content.tiles?.moment.date?.isEmpty == false)
        #expect(content.tiles?.moment.link == AppLink.moment(eventID: moment.eventID, childID: child.id).url)
        let mirror = String(describing: content)
        #expect(!mirror.contains("Ιδιωτικό σημείωμα"))
    }

    @Test("Given photos switched off, when presenting, then the moment shows without its photo")
    func photoSwitchedOff() {
        let content = HomeWidgetPresenter(locale: Self.english)
            .content(for: highlights(moment: moment, photo: Data("jpeg".utf8)), showsPhoto: false)

        #expect(content.tiles?.moment.photo == nil)
        #expect(content.tiles?.moment.title == "First steps")
    }

    @Test("Given no family yet, when presenting, then it asks to open the app")
    func noProfile() {
        let english = HomeWidgetPresenter(locale: Self.english).content(for: nil, showsPhoto: true)
        let greek = HomeWidgetPresenter(locale: Self.greek).content(for: nil, showsPhoto: true)

        #expect(english.message == "Open DadSaga to start the adventure.")
        #expect(greek.message == "Άνοιξε το DadSaga για να ξεκινήσει η περιπέτεια.")
        #expect(english.tiles == nil)
    }

    @Test("Given one child or several, when presenting, then the name shows only with siblings")
    func nameOnlyWithSiblings() {
        let sut = HomeWidgetPresenter(locale: Self.greek)
        #expect(sut.content(for: highlights(), showsPhoto: true).tiles?.childName == nil)
        #expect(sut.content(for: highlights(childCount: 2), showsPhoto: true).tiles?.childName == "Λένα")
    }

    @Test("Given the gallery and the loading state, when presenting, then neither carries family data")
    func sampleAndPlaceholder() {
        let sut = HomeWidgetPresenter(locale: Self.english)
        #expect(sut.sample.tiles?.quest.title == "Cuddle time")
        #expect(sut.sample.tiles?.moment.photo == nil)
        #expect(sut.placeholder.tiles?.quest.header == "Quest of the week")
        #expect(sut.placeholder.tiles?.moment.photo == nil)
    }
}
