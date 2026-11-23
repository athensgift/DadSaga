import SwiftData

/// An actor on the saga store's one queue and context (ADR-0068): one write at a time, each reading every row as last
/// saved. Conforms to `ModelActor` by hand: the macro would give it a context of its own. It is made with
/// `init(queue: DefaultSerialModelExecutor, container: ModelContainer)` and keeps the two as
/// `nonisolated let modelExecutor` and `modelContainer`, so the executor it returns is always the same object.
///
/// The initializer is not a requirement here: as a witness, Swift 6.4 marks it `nonisolated` and then refuses that on
/// an actor's synchronous initializer, in a clean build, depending on the order it checks the files in.
protocol SagaStoreActor: ModelActor {}
