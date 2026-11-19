import Application
import Foundation

/// `SoundtrackRepository` backed by `soundtracks.json` and the audio bundled next to it (ADR-0036 §8): the `SagaMusic`
/// bundle, which the app passes in. Loaded and validated once.
public actor BundledSoundtrackRepository: SoundtrackRepository {
    private let dataSource: JSONResourceDataSource
    private var cached: [Soundtrack]?

    public init(bundle: Bundle) {
        dataSource = JSONResourceDataSource(bundle: bundle)
    }

    public func fetchSoundtracks() async throws -> [Soundtrack] {
        if let cached { return cached }
        let soundtracks = try dataSource.decode([SoundtrackDTO].self, resource: "soundtracks").map {
            try $0.toDomain(audioURL: dataSource.url(of: $0.file))
        }
        try ContentValidator.validate(soundtracks)
        cached = soundtracks
        return soundtracks
    }
}
