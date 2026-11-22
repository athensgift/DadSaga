import Presentation
import UIKit

/// `BackgroundTime` from UIKit (ADR-0057 §6): a short trip out of the app doesn't stop an export or an import. When iOS
/// says time is up, the work is cancelled and the task ended before the handler returns, so the app isn't terminated.
struct UIKitBackgroundTime: BackgroundTime {
    func run<T: Sendable>(_ name: String, _ work: @escaping @Sendable () async throws -> T) async throws -> T {
        let task = Task { try await work() }
        let request = await BackgroundRequest(name: name) { task.cancel() }
        defer { Task { await request.end() } }
        do {
            return try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
        } catch {
            if await request.expired { throw BackgroundTimeExpired() }
            throw error
        }
    }
}

@MainActor
private final class BackgroundRequest {
    private var identifier = UIBackgroundTaskIdentifier.invalid
    private(set) var expired = false

    init(name: String, onExpiry: @escaping @Sendable () -> Void) {
        identifier = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            MainActor.assumeIsolated {
                self?.expired = true
                onExpiry()
                self?.end()
            }
        }
    }

    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
