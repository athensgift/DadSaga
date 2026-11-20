import Application
import CoreGraphics
import FilmKit
import Foundation
import HeroArt
import SwiftUI
import Synchronization

public enum SagaFilmRenderError: Error, Equatable {
    /// SwiftUI gave no image for a card.
    case cardNotDrawn
    /// The stand-in for a photo that can't be read couldn't be made.
    case pictureNotDrawn
}

/// Draws a saga film: its cards with SwiftUI, its photos through the photo use case, and the file with `FilmKit`
/// (ADR-0036 §3–§6, ADR-0037 §1).
///
/// Films are written under one folder, each in a folder of its own, and never kept: the folder is emptied before
/// every film and whenever `discardFilms()` is called.
public struct SagaFilmRenderer: SagaFilmRendering {
    private let getPhoto: any GetPhotoUseCase
    private let directory: URL
    /// The film's size as a share of 1080 × 1920 or 1920 × 1080. Only tests make smaller films.
    private let pixelScale: Double

    /// - Parameter directory: where films are written; everything in it is deleted with them.
    public init(
        getPhoto: any GetPhotoUseCase,
        directory: URL = FileManager.default.temporaryDirectory.appending(path: "SagaFilms", directoryHint: .isDirectory)
    ) {
        self.init(getPhoto: getPhoto, directory: directory, pixelScale: 1)
    }

    init(getPhoto: any GetPhotoUseCase, directory: URL, pixelScale: Double) {
        self.getPhoto = getPhoto
        self.directory = directory
        self.pixelScale = pixelScale
    }

    public func render(
        _ script: SagaFilmScript,
        progress: @escaping @MainActor @Sendable (Double) -> Void
    ) async throws -> URL {
        await discardFilms()
        let folder = directory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let url = folder.appending(path: script.title + ".mp4", directoryHint: .notDirectory)
        // The encoder reports after every frame, from its own task. Only whole percents go on, the newest waits if
        // the main actor is busy, and they arrive there in order.
        let (values, input) = AsyncStream.makeStream(of: Double.self, bufferingPolicy: .bufferingNewest(1))
        let shown = Task { @MainActor in
            for await value in values {
                progress(value)
            }
        }
        let percent = Mutex(-1)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let builder = SagaFilmTimelineBuilder(spec: spec(for: script.format), photos: SagaFilmPhotoLoader(getPhoto: getPhoto))
            try await FilmEncoder().encode(builder.timeline(for: script), to: url) { value in
                let whole = Int(value * 100)
                let isNew = percent.withLock { last in
                    guard whole > last else { return false }
                    last = whole
                    return true
                }
                if isNew {
                    input.yield(value)
                }
            }
            // The encoder looks for a cancel once a frame, so one that lands while the file is being finished comes
            // back as a film. The dad asked to stop: the film goes, as the protocol promises.
            try Task.checkCancellation()
            input.finish()
            await shown.value
            return url
        } catch {
            input.finish()
            await shown.value
            try? FileManager.default.removeItem(at: folder)
            throw error
        }
    }

    public func discardFilms() async {
        try? FileManager.default.removeItem(at: directory)
    }

    /// The card's layer as the film draws it, at the film's full size: transparent where a photo shows through.
    /// Snapshots use it.
    @MainActor
    public static func cardImage(_ card: SagaFilmCard, format: SagaFilmFormat) throws -> CGImage {
        let spec = format.spec
        return try cardImage(card, pixelSize: CGSize(width: spec.width, height: spec.height))
    }

    /// Everything a card's look could take from the device is pinned, so a film looks the same on every phone: dark,
    /// still avatars, and type sized from the frame alone.
    @MainActor
    static func cardImage(_ card: SagaFilmCard, pixelSize: CGSize) throws -> CGImage {
        let view = SagaFilmCardView(card: card, canvas: pixelSize)
            .environment(\.colorScheme, .dark)
            .environment(\.avatarsAreStill, true)
            .environment(\.dynamicTypeSize, .large)
            .environment(\.legibilityWeight, .regular)
            .environment(\.layoutDirection, .leftToRight)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(pixelSize)
        renderer.isOpaque = card.photoID == nil
        guard let image = renderer.cgImage else { throw SagaFilmRenderError.cardNotDrawn }
        return image
    }

    private func spec(for format: SagaFilmFormat) -> FilmSpec {
        let full = format.spec
        guard pixelScale != 1 else { return full }
        // H.264 needs even sides.
        func scaled(_ side: Int) -> Int { max(2, Int((Double(side) * pixelScale / 2).rounded()) * 2) }
        return FilmSpec(width: scaled(full.width), height: scaled(full.height))
    }
}

private extension SagaFilmFormat {
    var spec: FilmSpec {
        switch self {
        case .vertical: .vertical
        case .wide: .wide
        }
    }
}
