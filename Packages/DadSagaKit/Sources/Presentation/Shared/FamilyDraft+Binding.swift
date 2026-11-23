import SwiftUI

extension Binding where Value == FamilyDraft {
    /// One child of the family, found by id each time it is read or written, never by position: a card that is
    /// leaving still draws for a moment after its child is removed. Then it reads `child` as it was, and a write to it
    /// is dropped.
    func child(_ child: ChildDraft) -> Binding<ChildDraft> {
        Binding<ChildDraft>(
            get: { wrappedValue.children.first { $0.id == child.id } ?? child },
            set: { edited in
                guard let index = wrappedValue.children.firstIndex(where: { $0.id == child.id }) else { return }
                wrappedValue.children[index] = edited
            }
        )
    }
}
