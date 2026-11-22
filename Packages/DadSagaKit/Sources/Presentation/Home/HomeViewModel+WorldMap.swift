import Application
import Domain
import Foundation
import Localization

/// The world map: every world for the child home shows, each open at any time (ADR-0061 §3). Home's presenter owns it
/// and builds it again with every load, so the map tab always shows what home shows.
extension HomeViewModel {
    /// Shows a world's quests and bosses on home, any world of the catalog. `nil`, or the current world, goes back to
    /// the current one.
    public func showWorld(id: String?) async {
        guard let overview else { return }
        if let id, overview.catalog.world(id: id) == nil { return }
        viewedWorldID = id == overview.adventure.currentWorld?.id ? nil : id
        situationalVisit += 1
        await reload()
    }

    func makeWorldMap(_ overview: HomeOverview) -> WorldMapContent {
        let age = overview.adventure.age
        let reached = Set(overview.adventure.reachedWorlds.map(\.id))
        let shownID = overview.shownWorld?.id
        return WorldMapContent(
            title: strings.text("World map"),
            subtitle: "\(overview.child.name) · \(strings.ageText(age))",
            openTitle: strings.text("Open this world"),
            worlds: overview.catalog.worlds.map { world in
                let status: WorldMapItem.Status = world.id == overview.adventure.currentWorld?.id
                    ? .current
                    : reached.contains(world.id) ? .visited : .ahead
                let done = overview.progress.progress(in: world, catalog: overview.catalog, childID: overview.child.id)
                let hasDone = done.questsDone + done.bossesDone > 0
                let isShown = world.id == shownID
                return WorldMapItem(
                    id: world.id,
                    number: world.order,
                    title: world.title.resolved(for: locale),
                    tagline: world.tagline.resolved(for: locale),
                    ageRange: strings.ageRange(world.span),
                    status: status,
                    idealLine: status == .ahead ? strings.idealStart(world) : nil,
                    progress: status != .ahead || hasDone
                        ? strings.worldProgress(quests: done.questsDone, bosses: done.bossesDone)
                        : nil,
                    tag: status == .current
                        ? strings.text("You are here")
                        : isShown ? strings.text("Showing now") : nil,
                    isShown: isShown
                )
            }
        )
    }
}
