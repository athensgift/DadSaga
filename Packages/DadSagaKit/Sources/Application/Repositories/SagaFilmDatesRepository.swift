/// Port for the film sheet's "Dates in the film" switch (ADR-0041 §5). Remembered until the dad changes it, and kept
/// when he starts over: it is about how he shares from this iPhone, not about the saga.
public protocol SagaFilmDatesRepository: Sendable {
    /// On when nothing is stored.
    func showsDates() async -> Bool
    func setShowsDates(_ showsDates: Bool) async
}
