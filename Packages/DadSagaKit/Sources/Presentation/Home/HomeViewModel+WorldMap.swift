import Application
import Domain
import Foundation

/// The world map: every world for the selected child, and playing an earlier world's quests again.
extension HomeViewModel {
    public func openMap() {
        guard let snapshot else { return }
        worldMap = makeWorldMap(snapshot)
    }

    public func closeMap() {
        worldMap = nil
    }

    /// Shows an unlocked world's quests and bosses on home. `nil`, or the current world, goes back to the current one.
    public func showWorld(id: String?) async {
        guard let snapshot else { return }
        if let id, !snapshot.adventure.unlockedWorlds.contains(where: { $0.id == id }) { return }
        viewedWorldID = id == snapshot.adventure.currentWorld?.id ? nil : id
        worldMap = nil
        await reload()
    }

    func shownWorld(_ adventure: Adventure) -> World? {
        adventure.unlockedWorlds.first { $0.id == viewedWorldID } ?? adventure.currentWorld
    }

    private func makeWorldMap(_ snapshot: HomeSnapshot) -> WorldMapContent {
        let strings = HomeStrings(locale: locale)
        let age = snapshot.adventure.ageInMonths
        let unlocked = Set(snapshot.adventure.unlockedWorlds.map(\.id))
        let shownID = shownWorld(snapshot.adventure)?.id
        let completions = snapshot.progress.questCompletions(for: snapshot.child.id)
        let defeated = snapshot.progress.defeatedBossIDs(for: snapshot.child.id)
        return WorldMapContent(
            title: strings.text(el: "Χάρτης κόσμων", en: "World map"),
            subtitle: "\(snapshot.child.name) · \(strings.ageText(months: age))",
            worlds: snapshot.catalog.worlds.map { world in
                let status: WorldMapItem.Status = world.id == snapshot.adventure.currentWorld?.id
                    ? .current
                    : unlocked.contains(world.id) ? .visited : .locked
                // An evergreen quest counts only in its home world; a boss the family cannot meet does not count.
                let quests = snapshot.catalog.quests.filter { $0.worldID == world.id }
                let bosses = snapshot.catalog.bosses.filter {
                    $0.worldID == world.id && UnlockRules.isPossible($0, childCount: snapshot.childCount)
                }
                let detail = status == .locked
                    ? strings.unlocksIn(months: world.minAgeMonths - age)
                    : strings.worldProgress(
                        quests: quests.filter { completions[$0.id, default: 0] > 0 }.count,
                        bosses: bosses.filter { defeated.contains($0.id) }.count
                    )
                let isShown = world.id == shownID
                return WorldMapItem(
                    id: world.id,
                    number: world.order,
                    title: world.title.resolved(for: locale),
                    tagline: world.tagline.resolved(for: locale),
                    ageRange: strings.ageRange(from: world.minAgeMonths, to: world.maxAgeMonths),
                    status: status,
                    detail: detail,
                    tag: status == .current
                        ? strings.text(el: "Είσαι εδώ", en: "You are here")
                        : isShown ? strings.text(el: "Το βλέπεις τώρα", en: "Showing now") : nil,
                    isShown: isShown
                )
            }
        )
    }
}
