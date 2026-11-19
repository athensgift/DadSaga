/// Port for starting over: deletes the profile, the children, every event and the wardrobe in one write, so either
/// all of it goes or none of it does (ADR-0030).
public protocol SagaEraser: Sendable {
    func eraseAll() async throws
}
