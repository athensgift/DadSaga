import Application
import Foundation
@testable import Presentation

/// Doubles for the export and import presenters (`DataTransferTests`).

actor FakeMakeCopy: MakeSagaCopyUseCase {
    private let result: Result<MadeSagaCopy, any Error>
    private let waits: Bool
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var hasStarted = false

    init(result: Result<MadeSagaCopy, any Error>, waits: Bool = false) {
        self.result = result
        self.waits = waits
    }

    func execute(on date: Date, progress: @escaping @Sendable (Double) -> Void) async throws -> MadeSagaCopy {
        hasStarted = true
        startWaiters.forEach { $0.resume() }
        startWaiters = []
        progress(0.5)
        if waits { try await Task.sleep(for: .seconds(60)) }
        return try result.get()
    }

    func discardCopies() async {}

    func started() async {
        if hasStarted { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }
}

actor FakeRestore: RestoreSagaUseCase {
    private let copy: OpenedSagaCopy?
    private let failure: (any Error)?
    private let restoreFailure: (any Error)?
    private let waits: Bool
    private(set) var restored: [OpenedSagaCopy] = []
    private(set) var discarded: [OpenedSagaCopy] = []
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var hasStarted = false

    init(copy: OpenedSagaCopy?, failure: (any Error)? = nil, restoreFailure: (any Error)? = nil, waits: Bool = false) {
        self.copy = copy
        self.failure = failure
        self.restoreFailure = restoreFailure
        self.waits = waits
    }

    func open(fileAt url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> OpenedSagaCopy {
        hasStarted = true
        startWaiters.forEach { $0.resume() }
        startWaiters = []
        if waits { try await Task.sleep(for: .seconds(60)) }
        if let failure { throw failure }
        guard let copy else { throw SagaCopyError.notACopy }
        return copy
    }

    func restore(_ opened: OpenedSagaCopy, on date: Date) async throws {
        if let restoreFailure { throw restoreFailure }
        restored.append(opened)
    }

    func discard(_ opened: OpenedSagaCopy) async {
        discarded.append(opened)
    }

    func started() async {
        if hasStarted { return }
        await withCheckedContinuation { startWaiters.append($0) }
    }
}

/// iOS's time running out as soon as the work starts.
struct ExpiringBackgroundTime: BackgroundTime {
    func run<T: Sendable>(_ name: String, _ work: @escaping @Sendable () async throws -> T) async throws -> T {
        throw BackgroundTimeExpired()
    }
}
