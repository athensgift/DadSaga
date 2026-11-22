/// Time iOS gives the app to finish work after it leaves the screen (ADR-0057 §6). The app's own one asks UIKit; tests
/// and previews run the work as it is.
public protocol BackgroundTime: Sendable {
    /// Runs `work`, asking iOS for time to finish it if the app leaves the screen. When that time runs out, `work` is
    /// cancelled and this throws `BackgroundTimeExpired`.
    func run<T: Sendable>(_ name: String, _ work: @escaping @Sendable () async throws -> T) async throws -> T
}

/// iOS stopped the work when the app had been away from the screen too long.
public struct BackgroundTimeExpired: Error, Equatable {
    public init() {}
}

/// Runs the work with no extra time: for tests, previews and anywhere iOS gives none.
public struct ImmediateBackgroundTime: BackgroundTime {
    public init() {}

    public func run<T: Sendable>(_ name: String, _ work: @escaping @Sendable () async throws -> T) async throws -> T {
        try await work()
    }
}
