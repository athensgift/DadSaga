import Foundation

/// Draws a saga film from its script and writes it to a file (ADR-0036 §5). The view model holds this protocol, so
/// it needs neither SwiftUI nor AVFoundation; `SagaFilmRenderer` is the implementation.
public protocol SagaFilmRendering: Sendable {
    /// Deletes every earlier film, writes this one to a new temporary file and returns it. Cancelling the calling
    /// task stops it with `CancellationError` and leaves no file.
    ///
    /// - Parameter progress: rising, and 1 once the file is complete; called on the main actor, in order, and never
    ///   after this returns or throws.
    func render(_ script: SagaFilmScript, progress: @escaping @MainActor @Sendable (Double) -> Void) async throws -> URL

    /// Deletes every film this renderer made. Never fails.
    func discardFilms() async
}
