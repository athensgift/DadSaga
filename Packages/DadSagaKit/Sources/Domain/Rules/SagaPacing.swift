import Foundation

/// How long each scene of a saga film lasts, and how long a film may be (ADR-0036).
public struct SagaPacing: Hashable, Sendable {
    public var opening: TimeInterval
    public var chapter: TimeInterval
    public var firstWithPhoto: TimeInterval
    public var firstWithoutPhoto: TimeInterval
    public var boss: TimeInterval
    public var questPhoto: TimeInterval
    public var credits: TimeInterval
    /// The film's target length. Only firsts that no longer fit at `firstFloor` can take it past this.
    public var maxSeconds: TimeInterval
    /// The shortest a first's scene gets when the film is too long.
    public var firstFloor: TimeInterval

    public init(
        opening: TimeInterval = 3.5,
        chapter: TimeInterval = 2.5,
        firstWithPhoto: TimeInterval = 4.5,
        firstWithoutPhoto: TimeInterval = 3,
        boss: TimeInterval = 3.5,
        questPhoto: TimeInterval = 2.5,
        credits: TimeInterval = 6,
        maxSeconds: TimeInterval = 90,
        firstFloor: TimeInterval = 3
    ) {
        self.opening = opening
        self.chapter = chapter
        self.firstWithPhoto = firstWithPhoto
        self.firstWithoutPhoto = firstWithoutPhoto
        self.boss = boss
        self.questPhoto = questPhoto
        self.credits = credits
        self.maxSeconds = maxSeconds
        self.firstFloor = firstFloor
    }

    public static let standard = SagaPacing()
}
