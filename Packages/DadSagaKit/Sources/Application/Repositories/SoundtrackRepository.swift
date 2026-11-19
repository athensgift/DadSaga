import Foundation

/// A piece of music bundled with the app for saga films, with its credit (ADR-0036).
public struct Soundtrack: Hashable, Sendable {
    public let id: String
    public let title: String
    public let artist: String
    public let licence: SoundtrackLicence
    public let audioURL: URL

    public init(id: String, title: String, artist: String, licence: SoundtrackLicence, audioURL: URL) {
        self.id = id
        self.title = title
        self.artist = artist
        self.licence = licence
        self.audioURL = audioURL
    }
}

/// The only licences a bundled track may have (ADR-0036 §8).
public enum SoundtrackLicence: String, Hashable, Sendable {
    /// Made for the app, without Apple Loops.
    case original
    /// Public domain dedication; the licence page is archived in the repository.
    case cc0
}

/// Port for the bundled film music. Implemented in the Data layer.
public protocol SoundtrackRepository: Sendable {
    /// In the order they are bundled.
    func fetchSoundtracks() async throws -> [Soundtrack]
}
