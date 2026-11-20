/// Remembers the film's music (ADR-0046 §4).
public protocol SetSagaFilmMusicUseCase: Sendable {
    func execute(soundtrackID: String) async
}

public struct DefaultSetSagaFilmMusicUseCase: SetSagaFilmMusicUseCase {
    private let repository: any SagaFilmChoicesRepository

    public init(repository: any SagaFilmChoicesRepository) {
        self.repository = repository
    }

    public func execute(soundtrackID: String) async {
        await repository.setSoundtrackID(soundtrackID)
    }
}
