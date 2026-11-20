/// Remembers that the dad answered home's film offer for an occasion, yes or no, so it is never offered again
/// (ADR-0037 §5).
public protocol AnswerSagaOfferUseCase: Sendable {
    func execute(occasionID: String) async
}

public struct DefaultAnswerSagaOfferUseCase: AnswerSagaOfferUseCase {
    private let repository: any SagaOfferRepository

    public init(repository: any SagaOfferRepository) {
        self.repository = repository
    }

    public func execute(occasionID: String) async {
        await repository.markAnswered(occasionID)
    }
}
