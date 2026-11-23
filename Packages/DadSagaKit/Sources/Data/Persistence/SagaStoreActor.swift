import SwiftData

/// An actor on the saga store's one queue and context (ADR-0068): one write at a time, each reading every row as last
/// saved. Conforms to `ModelActor` by hand: the macro would give it a context of its own. It keeps the two things it is
/// made with as `nonisolated let modelExecutor` and `modelContainer`, so the executor it returns is always the same
/// object.
protocol SagaStoreActor: ModelActor {
    init(queue: DefaultSerialModelExecutor, container: ModelContainer)
}
