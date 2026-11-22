import Domain
import Foundation

/// Chooses which of an entry's further photos fill its places in a film, by the device's rating (ADR-0047 §2). Run
/// as the film is made, never by the film sheet's query; only the photos that can change the film are looked at.
public protocol ChooseSagaFilmPhotosUseCase: Sendable {
    /// The same film, its further photos chosen. When the task is cancelled, or nothing can be rated, the film as given.
    func execute(_ film: SagaFilm) async -> SagaFilm
}

public struct DefaultChooseSagaFilmPhotosUseCase: ChooseSagaFilmPhotosUseCase {
    /// A rating needs no more than this: smaller is quicker to read and to look at.
    static let ratingPixelSize = 512
    /// Photos looked at together: enough to overlap reading and looking, few enough for an old phone.
    static let together = 2

    private let photoStore: any PhotoStore
    private let analyzer: any PhotoAnalyzer

    public init(photoStore: any PhotoStore, analyzer: any PhotoAnalyzer) {
        self.photoStore = photoStore
        self.analyzer = analyzer
    }

    public func execute(_ film: SagaFilm) async -> SagaFilm {
        let ids = film.storyboard.photoChoices.flatMap(\.candidates)
        guard !ids.isEmpty else { return film }
        let ratings = await withTaskGroup(of: (String, PhotoRating?).self) { group in
            var ratings: [String: PhotoRating] = [:]
            var pending = ids.makeIterator()
            func next() -> Bool {
                guard let id = pending.next() else { return false }
                group.addTask { [photoStore, analyzer] in
                    guard !Task.isCancelled,
                          let data = await photoStore.thumbnail(id: id, maxPixelSize: Self.ratingPixelSize)
                    else { return (id, nil) }
                    return (id, await analyzer.rating(of: data))
                }
                return true
            }
            for _ in 0..<Self.together where next() {}
            for await (id, rating) in group {
                ratings[id] = rating
                _ = next()
            }
            return ratings
        }
        guard !Task.isCancelled else { return film }
        return film.replacing(storyboard: film.storyboard.choosingPhotos(by: ratings))
    }
}

/// What a film's camera looks at in a photo (ADR-0047 §3): the children, else every face, else what draws the eye.
public protocol FindPhotoSubjectUseCase: Sendable {
    /// `nil` when nothing was found: the film then moves as it always has.
    func execute(photo imageData: Data) async -> PhotoFraming?
}

public struct DefaultFindPhotoSubjectUseCase: FindPhotoSubjectUseCase {
    private let analyzer: any PhotoAnalyzer

    public init(analyzer: any PhotoAnalyzer) {
        self.analyzer = analyzer
    }

    public func execute(photo imageData: Data) async -> PhotoFraming? {
        let faces = await analyzer.faces(in: imageData)
        guard faces.isEmpty else { return PhotoSubject.framing(faces: faces, salientObjects: []) }
        return PhotoSubject.framing(faces: [], salientObjects: await analyzer.salientObjects(in: imageData))
    }
}

extension SagaFilm {
    func replacing(storyboard: SagaStoryboard) -> SagaFilm {
        SagaFilm(
            profile: profile,
            child: child,
            catalog: catalog,
            storyboard: storyboard,
            availablePeriods: availablePeriods,
            medalCount: medalCount,
            childFirsts: childFirsts,
            equippedGear: equippedGear,
            title: title,
            soundtracks: soundtracks,
            soundtrack: soundtrack,
            showsDates: showsDates
        )
    }
}
