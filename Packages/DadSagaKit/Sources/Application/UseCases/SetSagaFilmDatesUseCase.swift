/// Remembers whether films show dates (ADR-0041 §5).
public protocol SetSagaFilmDatesUseCase: Sendable {
    func execute(showsDates: Bool) async
}

public struct DefaultSetSagaFilmDatesUseCase: SetSagaFilmDatesUseCase {
    private let repository: any SagaFilmDatesRepository

    public init(repository: any SagaFilmDatesRepository) {
        self.repository = repository
    }

    public func execute(showsDates: Bool) async {
        await repository.setShowsDates(showsDates)
    }
}
