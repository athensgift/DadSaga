import Domain
import Foundation
import SwiftUI
import Testing
@testable import Presentation

/// A child card reads and writes its child by id: the last card still draws while it leaves, after its child is
/// removed, and must not reach for a place that is gone.
@MainActor
@Suite("A child card's binding")
struct FamilyDraftBindingTests {
    final class Box {
        var family = FamilyDraft(children: [
            ChildDraft(name: "Λένα", birthDay: .day(2024, 1, 1)), ChildDraft(name: "Νίκος", birthDay: .day(2025, 1, 1))
        ])
    }

    @Test("Given the last child's card, when that child is removed, then the card still reads them and a write is dropped")
    func removedLastChild() {
        let box = Box()
        let family = Binding(get: { box.family }, set: { box.family = $0 })
        let last = box.family.children[1]
        let card = family.child(last)

        box.family.removeChild(id: last.id)
        card.wrappedValue.name = "Άλλος"

        #expect(card.wrappedValue.name == "Νίκος")
        #expect(box.family.children.map(\.name) == ["Λένα"])
    }

    @Test("Given a child's card, when a child before them is removed, then the card still edits that child")
    func removedEarlierChild() {
        let box = Box()
        let family = Binding(get: { box.family }, set: { box.family = $0 })
        let card = family.child(box.family.children[1])

        box.family.removeChild(id: box.family.children[0].id)
        card.wrappedValue.name = "Νικόλας"

        #expect(box.family.children.map(\.name) == ["Νικόλας"])
        #expect(box.family.number(of: card.wrappedValue.id) == 1)
    }
}
