/// Runs operations one at a time, in the order they were added. An actor runs other calls whenever one of its methods
/// awaits; what must not be interleaved goes through one of these instead.
struct SerialTaskQueue {
    private var last: Task<Void, Never>?

    /// Starts `operation` once every one added before it has ended. Await the task for its result.
    mutating func add<Success: Sendable>(_ operation: @escaping @Sendable () async -> Success) -> Task<Success, Never> {
        let previous = last
        let task = Task {
            await previous?.value
            return await operation()
        }
        last = Task { _ = await task.value }
        return task
    }
}
