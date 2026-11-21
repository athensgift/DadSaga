import Application
import Domain
import Foundation
import Localization

/// The world map: every world for the selected child, and playing an earlier world's quests again.
extension HomeViewModel {
    public func openMap() {
        guard let overview else { return }
        worldMap = makeWorldMap(overview)
    }

    public func closeMap() {
        worldMap = nil
    }

    /// Shows an unlocked world's quests and bosses on home. `nil`, or the current world, goes back to the current one.
    public func showWorld(id: String?) async {
        guard let overview else { return }
        if let id, !overview.adventure.unlockedWorlds.contains(where: { $0.id == id }) { return }
        viewedWorldID = id == overview.adventure.currentWorld?.id ? nil : id
        worldMap = nil
        await reload()
    }

    private func makeWorldMap(_ overview: HomeOverview) -> WorldMapContent {
        let strings = HomeStrings(locale: locale)
        let age = overview.adventure.age
        let unlocked = Set(overview.adventure.unlockedWorlds.map(\.id))
        let shownID = overview.shownWorld?.id
        return WorldMapContent(
            title: strings.text("World map"),
            subtitle: "\(overview.child.name) · \(strings.ageText(age))",
            worlds: overview.catalog.worlds.map { world in
                let status: WorldMapItem.Status = world.id == overview.adventure.currentWorld?.id
                    ? .current
                    : unlocked.contains(world.id) ? .visited : .locked
                let done = overview.progress.progress(in: world, catalog: overview.catalog, childID: overview.child.id)
                let detail = status == .locked
                    ? strings.unlocks(world, at: age)
                    : strings.worldProgress(quests: done.questsDone, bosses: done.bossesDone)
                let isShown = world.id == shownID
                return WorldMapItem(
                    id: world.id,
                    number: world.order,
                    title: world.title.resolved(for: locale),
                    tagline: world.tagline.resolved(for: locale),
                    ageRange: strings.ageRange(world.span),
                    status: status,
                    detail: detail,
                    tag: status == .current
                        ? strings.text("You are here")
                        : isShown ? strings.text("Showing now") : nil,
                    isShown: isShown
                )
            }
        )
    }
}
