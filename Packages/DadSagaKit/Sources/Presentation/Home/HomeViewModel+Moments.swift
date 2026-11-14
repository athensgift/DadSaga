import Foundation

/// Legendary moments: capture a first for the selected child.
extension HomeViewModel {
    public func startCapture() {
        guard let snapshot else { return }
        errorMessage = nil
        momentCapture = momentsFormatter.capture(
            for: snapshot.child,
            catalog: snapshot.catalog,
            progress: snapshot.progress,
            now: now()
        )
    }

    public func dismissCapture() {
        momentCapture = nil
        errorMessage = nil
    }

    public func captureMoment(firstID: String, date: Date, note: String) async {
        guard let childID = selectedChildID,
              let option = momentCapture?.options.first(where: { $0.id == firstID }) else { return }
        await record(badge: nil, moment: "\(option.emoji) \(option.title)") {
            try await self.useCases.captureMoment.execute(
                firstID: firstID,
                childID: childID,
                happenedOn: date,
                note: note,
                now: self.now()
            )
        }
    }
}
