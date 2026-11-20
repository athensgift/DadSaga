/// What the film sheet remembers until the dad changes it (ADR-0041 §5, ADR-0046 §4). Kept when he starts over: it
/// is about how he makes films on this iPhone, not about the saga.
public protocol SagaFilmChoicesRepository: Sendable {
    /// On when nothing is stored.
    func showsDates() async -> Bool
    func setShowsDates(_ showsDates: Bool) async
    /// The track last chosen; `nil` until the dad chooses one.
    func soundtrackID() async -> String?
    func setSoundtrackID(_ id: String) async
}
