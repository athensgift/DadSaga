import Foundation
@testable import Presentation
import Testing

@Suite("Photo viewer content")
struct PhotoViewerContentTests {
    let photos: [PhotoSource] = [.stored("a"), .stored("b"), .data(Data([1]))]

    @Test("Given an entry's three photos in Greek, when opened at the second, then each page says which photo it is")
    func greek() {
        let labels = PhotoViewerLabels(locale: Locale(identifier: "el_GR"))

        let content = labels.content(entry: "👣 Βήματα", photos: photos, startingAt: 1)

        #expect(content.startIndex == 1)
        #expect(content.pages.map(\.label) == [
            "Φωτογραφία 1 από 3, 👣 Βήματα", "Φωτογραφία 2 από 3, 👣 Βήματα", "Φωτογραφία 3 από 3, 👣 Βήματα"
        ])
        #expect(content.pages.map(\.source) == photos)
        #expect(content.counter(at: 1) == "2 / 3")
        #expect(content.closeTitle == "Κλείσιμο")
        #expect(content.pages.map(\.missingText) == Array(repeating: "Αυτή η φωτογραφία δεν μπορεί να εμφανιστεί.", count: 3))
        #expect(labels.showPhotos == "Δες τις φωτογραφίες")
        #expect(labels.photoCount(1) == "1 φωτογραφία")
        #expect(labels.photoCount(3) == "3 φωτογραφίες")
        #expect(labels.photoCount(0) == nil)
    }

    @Test("Given English, when opened, then the labels and the count are in English")
    func english() {
        let labels = PhotoViewerLabels(locale: Locale(identifier: "en_US"))

        let content = labels.content(entry: "👣 Steps", photos: photos)

        #expect(content.pages.first?.label == "Photo 1 of 3, 👣 Steps")
        #expect(content.closeTitle == "Close")
        #expect(content.pages.first?.missingText == "This photo can't be shown.")
        #expect(labels.showPhotos == "Show photos")
        #expect(labels.photoCount(1) == "1 photo")
        #expect(labels.photoCount(2) == "2 photos")
    }

    @Test("Given one photo or a page past the end, when opened, then there is no counter, or it opens at the last")
    func edges() {
        let labels = PhotoViewerLabels(locale: Locale(identifier: "en_US"))
        #expect(labels.content(entry: "x", photos: [.stored("a")]).counter(at: 0) == nil)
        #expect(labels.content(entry: "x", photos: photos, startingAt: 7).startIndex == 2)
    }
}
