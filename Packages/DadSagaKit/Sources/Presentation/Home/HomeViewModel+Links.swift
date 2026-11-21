import Application
import Foundation

/// Links from outside the app, such as the home-screen widget (ADR-0023). They only open a screen, never record.
extension HomeViewModel {
    /// Shows the link's child, then the quest's sheet or the moment. A child no longer in the family opens home
    /// as it is; a quest or moment that no longer exists opens no sheet.
    public func open(_ link: AppLink) async {
        dismissSelection()
        worldMap = nil
        selectedChildID = link.childID
        viewedWorldID = nil
        await reload()
        guard let overview, overview.child.id == link.childID else { return }
        switch link {
        case .quest(let id, _):
            // From the whole catalog, not just the shown world: last week's quest may belong to the previous one.
            guard let quest = overview.catalog.quest(id: id),
                  quest.minAgeMonths <= overview.adventure.ageInMonths else { return }
            selectedQuest = detail(for: quest)
        case .moment(let eventID, _):
            editMoment(id: eventID)
        case .child:
            break
        }
    }

    /// The link the root screen is holding, as the view passes it on.
    public func open(_ pending: PendingLink) async {
        await open(pending.link)
    }
}
