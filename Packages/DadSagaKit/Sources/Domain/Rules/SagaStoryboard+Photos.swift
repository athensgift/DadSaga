import Foundation

/// An entry with more further photos than places in its film (ADR-0047 §2): the photos the device may choose among.
public struct SagaPhotoChoice: Hashable, Sendable {
    public let entryID: UUID
    /// The entry's further photos that can be read, in the dad's order.
    public let candidates: [String]
    /// The photos that fill its places by position, in the film's order.
    public let chosen: [String]
}

public extension SagaStoryboard {
    /// The photos whose file decides what the film shows (ADR-0075): every photo shown alone, without words (a
    /// quest's cover, each further photo), and every further photo that could take the place of one of those. A
    /// first's or a boss's cover isn't among them: its words stay on the dark either way (ADR-0037 §2).
    var photosShownAlone: Set<String> {
        var photos: Set<String> = []
        for scene in scenes {
            switch scene.kind {
            case .entry(let entry):
                if case .quest = entry.kind, let cover = entry.coverPhotoID { photos.insert(cover) }
            case .photo(let entry, let id):
                photos.insert(id)
                photos.formUnion(entry.photoIDs.dropFirst())
            case .opening, .chapter, .credits:
                break
            }
        }
        return photos
    }

    /// The entries whose readable further photos don't all fit in the film, oldest first.
    ///
    /// - Parameter unreadable: photos whose file is missing or damaged: never a candidate.
    func photoChoices(leavingOut unreadable: Set<String> = []) -> [SagaPhotoChoice] {
        furtherPhotos(leavingOut: unreadable).compactMap { further in
            guard further.places.count < further.candidates.count else { return nil }
            return SagaPhotoChoice(entryID: further.entry.id, candidates: further.candidates, chosen: further.places)
        }
    }

    /// The same film with each entry's places filled by its best rated further photos: moments before utility photos,
    /// then the higher score, played in the dad's order. An entry keeps its photos as they are when any of its
    /// candidates has no rating, or all of them rate the same.
    ///
    /// A photo in `unreadable` never plays alone (ADR-0075). Its place goes to the entry's next readable further
    /// photo; with none left, the place goes, and so does the scene of a quest whose cover can't be read, and a
    /// chapter card left with nothing after it. Every scene kept keeps its length, so the film only gets shorter.
    func choosingPhotos(by ratings: [String: PhotoRating], leavingOut unreadable: Set<String> = []) -> SagaStoryboard {
        var refill: [UUID: [String]] = [:]
        for further in furtherPhotos(leavingOut: unreadable) {
            let photos = further.best(by: ratings) ?? further.places
            if photos != further.shown {
                refill[further.entry.id] = photos
            }
        }
        let hasUnreadableCover = scenes.contains { Self.isQuest($0, withCoverIn: unreadable) }
        guard !refill.isEmpty || hasUnreadableCover else { return self }

        let kept = keptScenes(refilling: refill, leavingOut: unreadable)
        return SagaStoryboard(period: period, asOf: asOf, childAge: childAge, span: span, scenes: Self.withChapters(kept))
    }

    /// Each scene kept, with the chapter card it came under: entries' places as `refill` fills them, and no quest
    /// whose cover is in `unreadable`.
    private func keptScenes(
        refilling refill: [UUID: [String]], leavingOut unreadable: Set<String>
    ) -> [(scene: SagaScene, chapter: SagaScene?)] {
        var kept: [(scene: SagaScene, chapter: SagaScene?)] = []
        var chapter: SagaScene?
        var next: [UUID: Int] = [:]
        for scene in scenes {
            switch scene.kind {
            case .chapter:
                chapter = scene
            case .entry:
                if !Self.isQuest(scene, withCoverIn: unreadable) { kept.append((scene, chapter)) }
            case .photo(let entry, _):
                guard let photos = refill[entry.id] else {
                    kept.append((scene, chapter))
                    continue
                }
                let index = next[entry.id, default: 0]
                next[entry.id] = index + 1
                if index < photos.count {
                    kept.append((SagaScene(kind: .photo(entry, id: photos[index]), seconds: scene.seconds), chapter))
                }
            case .opening, .credits:
                kept.append((scene, nil))
            }
        }
        return kept
    }

    /// One entry's further photos in the film.
    private struct FurtherPhotos {
        let entry: TimelineEntry
        /// The photos its scenes show now, in the film's order.
        let shown: [String]
        /// Its further photos that can be read, in the dad's order.
        let candidates: [String]
        /// What fills its places by position: the readable photos it shows, then the next readable ones, in the dad's
        /// order. Fewer than `shown` when too few can be read.
        let places: [String]

        /// Its best rated candidates for its places, in the dad's order; `nil` when they all fit, any has no rating,
        /// or all rate the same.
        func best(by ratings: [String: PhotoRating]) -> [String]? {
            let rated = candidates.compactMap { ratings[$0] }
            guard places.count < candidates.count, rated.count == candidates.count, Set(rated).count > 1 else {
                return nil
            }
            return zip(candidates.indices, rated)
                .sorted { first, second in
                    let (one, two) = (first.1, second.1)
                    if one.isUtility != two.isUtility { return !one.isUtility }
                    if one.score != two.score { return one.score > two.score }
                    return first.0 < second.0
                }
                .prefix(places.count)
                .map(\.0)
                .sorted()
                .map { candidates[$0] }
        }
    }

    /// The entries with further photos in the film, oldest first.
    private func furtherPhotos(leavingOut unreadable: Set<String>) -> [FurtherPhotos] {
        var entries: [TimelineEntry] = []
        var shown: [UUID: [String]] = [:]
        for scene in scenes {
            guard case .photo(let entry, let id) = scene.kind else { continue }
            if shown[entry.id] == nil {
                entries.append(entry)
            }
            shown[entry.id, default: []].append(id)
        }
        return entries.map { entry in
            let now = shown[entry.id] ?? []
            let candidates = entry.photoIDs.dropFirst().filter { !unreadable.contains($0) }
            let staying = now.filter { !unreadable.contains($0) }
            let stepping = candidates.filter { !staying.contains($0) }.prefix(max(0, now.count - staying.count))
            let places = candidates.filter { staying.contains($0) || stepping.contains($0) }
            return FurtherPhotos(entry: entry, shown: now, candidates: candidates, places: places)
        }
    }

    private static func isQuest(_ scene: SagaScene, withCoverIn photos: Set<String>) -> Bool {
        guard case .entry(let entry) = scene.kind, case .quest = entry.kind, let cover = entry.coverPhotoID else {
            return false
        }
        return photos.contains(cover)
    }

    /// The scenes with a chapter card at each change of world, counted from 1: only for the worlds that still have a
    /// scene, and none when one world is left.
    private static func withChapters(_ kept: [(scene: SagaScene, chapter: SagaScene?)]) -> [SagaScene] {
        func world(of chapter: SagaScene?) -> World? {
            if case .chapter(let world, _) = chapter?.kind { world } else { nil }
        }
        let hasChapters = Set(kept.compactMap { world(of: $0.chapter)?.id }).count > 1
        var scenes: [SagaScene] = []
        var worldID: String?
        var number = 0
        for (scene, chapter) in kept {
            if hasChapters, let chapter, let world = world(of: chapter), world.id != worldID {
                worldID = world.id
                number += 1
                scenes.append(SagaScene(kind: .chapter(world, number: number), seconds: chapter.seconds))
            }
            scenes.append(scene)
        }
        return scenes
    }
}
