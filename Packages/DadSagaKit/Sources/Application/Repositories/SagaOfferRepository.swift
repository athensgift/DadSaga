/// Port for the dad's answers to home's film offers (ADR-0036 §7, ADR-0037 §5). An answer is for one occasion and is
/// never taken back, so "Not now" means that occasion is not offered again.
public protocol SagaOfferRepository: Sendable {
    /// The ids of the occasions the dad has answered, either way.
    func answeredOccasionIDs() async -> Set<String>
    func markAnswered(_ occasionID: String) async
    /// Only starting over uses this.
    func deleteAll() async
}
