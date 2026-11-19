import Testing

/// Every FilmKit test writes a real film. They run one at a time: several writers at once would only slow each other
/// down, and a film that never finishes has to fail its test, not hang the run.
@Suite("FilmKit", .serialized, .timeLimit(.minutes(1)))
enum FilmKitTests {}
