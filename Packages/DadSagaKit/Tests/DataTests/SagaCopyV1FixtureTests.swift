import Application
import Domain
import Foundation
import Testing
@testable import Data

/// Every later version reads format 1 (ADR-0057 §4): the file in `Fixtures/SagaCopyV1` was written by the build that
/// introduced it.
@Suite("A copy in format 1")
struct SagaCopyV1FixtureTests {
    @Test("Given the format-1 copy, when reading it, then it is the saga it was made from, its photos byte for byte")
    func readsFormat1() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "dadsaga-copy-v1-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let photos = FilePhotoStore.moments(in: folder)
        let files = AppleArchiveSagaCopyFiles(app: "test", folder: folder.appending(path: "tmp"))
        let adopted = AdoptedIDs()

        let copy = try await files.read(fileAt: SagaCopyV1Fixture.file, adopt: { data in
            let id = try await photos.adopt(data)
            await adopted.append(id)
            return id
        }, progress: { _ in })

        let ids = await adopted.ids
        #expect(copy == SagaCopy(
            saga: SagaCopyV1Fixture.copy.saga.replacingPhotoIDs(
                Dictionary(uniqueKeysWithValues: zip(SagaCopyV1Fixture.photoIDs, ids))
            ),
            answeredOccasionIDs: SagaCopyV1Fixture.copy.answeredOccasionIDs,
            madeAt: SagaCopyV1Fixture.copy.madeAt
        ))
        for (original, new) in zip(SagaCopyV1Fixture.photoIDs, ids) {
            #expect(try await photos.storedData(id: new) == Data(contentsOf: SagaCopyV1Fixture.photo(original)))
        }
    }
}

actor AdoptedIDs {
    private(set) var ids: [String] = []
    func append(_ id: String) { ids.append(id) }
}
