public struct LevelProgress: Hashable, Sendable {
    public let level: Int
    public let xpIntoLevel: Int
    public let xpNeededForNextLevel: Int

    public var fraction: Double {
        guard xpNeededForNextLevel > 0 else { return 0 }
        return Double(xpIntoLevel) / Double(xpNeededForNextLevel)
    }
}

/// Triangular curve: level L needs 100 · (L−1) · L / 2 total XP (L2 = 100, L3 = 300, L4 = 600 …).
public enum LevelCurve {
    public static func totalXP(toReach level: Int) -> Int {
        guard level > 1 else { return 0 }
        return 100 * (level - 1) * level / 2
    }

    public static func level(forTotalXP xp: Int) -> Int {
        var level = 1
        while totalXP(toReach: level + 1) <= xp { level += 1 }
        return level
    }

    public static func progress(forTotalXP xp: Int) -> LevelProgress {
        let xp = max(0, xp)
        let level = level(forTotalXP: xp)
        let floor = totalXP(toReach: level)
        let ceiling = totalXP(toReach: level + 1)
        return LevelProgress(level: level, xpIntoLevel: xp - floor, xpNeededForNextLevel: ceiling - floor)
    }
}
