import Foundation
import Testing
@testable import Presentation

/// A link from outside closes the import's question and its file picker (ADR-0061 §2).
extension DataTransferTests {
    @Test("Given the question, when a link is about to open home, then it closes, what was read goes, nothing is imported")
    func linkClosesTheQuestion() async {
        let restore = FakeRestore(copy: copy(names: ["Lena"]))
        let sut = importer(restore)
        await sut.picked(URL(filePath: "/picked.dadsaga"))

        await sut.linkWillOpen()

        #expect(sut.state == .ready)
        #expect(await restore.discarded.count == 1)
        #expect(await restore.restored.isEmpty)
    }

    @Test("Given the file picker open, when a link is about to open home, then it closes")
    func linkClosesTheFilePicker() async {
        let sut = importer(FakeRestore(copy: nil))
        sut.pick()
        #expect(sut.isPicking)

        await sut.linkWillOpen()

        #expect(!sut.isPicking)
    }
}
