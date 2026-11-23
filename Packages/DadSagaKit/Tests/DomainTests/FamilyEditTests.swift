import Domain
import Foundation
import Testing

/// What "My family" sends: the difference from what it showed, never the whole family (ADR-0065 §4, §8).
@Suite("FamilyEdit")
struct FamilyEditTests {
    let lena = Child(name: "Λένα", birthDay: .day(2025, 3, 1), gender: .girl, skinTone: .light)
    let nikos = Child(name: "Νίκος", birthDay: nil)

    func renamed(_ child: Child, _ name: String) -> Child {
        var child = child
        child.name = name
        return child
    }

    @Test("Given the same family shown and saved, then the edit is empty")
    func nothingChanged() {
        let edit = FamilyEdit(shown: [lena, nikos], hasPartner: true, edited: [lena, nikos], hasPartner: true)
        #expect(edit.isEmpty)
        #expect(edit == FamilyEdit())
    }

    @Test("Given one child renamed, then only that child changes, and only its name")
    func oneRename() {
        let edit = FamilyEdit(
            shown: [lena, nikos], hasPartner: true, edited: [renamed(lena, "Ελένη"), nikos], hasPartner: true
        )
        #expect(edit.changed == [ChildEdit(child: renamed(lena, "Ελένη"), fields: [.name])])
        #expect(edit.added.isEmpty && edit.removedIDs.isEmpty && edit.hasPartner == nil)
    }

    @Test("Given a birth day set on a child not born, and one cleared, then only birthDay changes for each")
    func birthDays() {
        var born = nikos
        born.birthDay = .day(2026, 11, 1)
        var notBorn = lena
        notBorn.birthDay = nil
        let edit = FamilyEdit(shown: [lena, nikos], hasPartner: true, edited: [notBorn, born], hasPartner: true)
        #expect(edit.changed.map(\.fields) == [[.birthDay], [.birthDay]])
        #expect(edit.changed.map(\.child.birthDay) == [nil, .day(2026, 11, 1)])
    }

    @Test("Given gender and skin tone changed, then just those two fields")
    func genderAndTone() {
        var changed = nikos
        changed.gender = .girl
        changed.skinTone = .dark
        let edit = FamilyEdit(shown: [nikos], hasPartner: true, edited: [changed], hasPartner: true)
        #expect(edit.changed.first?.fields == [.gender, .skinTone])
    }

    @Test("Given a child added, one removed and the partner answer changed, then the edit says so")
    func addRemovePartner() {
        let iris = Child(name: "Ίρις", birthDay: nil)
        let edit = FamilyEdit(shown: [lena, nikos], hasPartner: true, edited: [lena, iris], hasPartner: false)
        #expect(edit.added == [iris])
        #expect(edit.removedIDs == [nikos.id])
        #expect(edit.changed.isEmpty)
        #expect(edit.hasPartner == false)
        let back = FamilyEdit(shown: [lena], hasPartner: false, edited: [lena], hasPartner: false)
        #expect(back.hasPartner == nil)
    }

    @Test("Given the family changed since the editor opened, when applied, then the other changes stay and only mine land")
    func appliedOverAChangedFamily() {
        // The partner added Ίρις and renamed Νίκος meanwhile; I renamed Λένα.
        let iris = Child(name: "Ίρις", birthDay: nil)
        let now = [lena, renamed(nikos, "Νικόλας"), iris]
        let mine = FamilyEdit(
            shown: [lena, nikos], hasPartner: true, edited: [renamed(lena, "Ελένη"), nikos], hasPartner: true
        )
        #expect(mine.applied(to: now).map(\.name) == ["Ελένη", "Νικόλας", "Ίρις"])
    }

    @Test("Given a change to a child no longer there and an added id already there, when applied, then neither lands twice")
    func appliedIgnoresWhatIsGone() {
        let edit = FamilyEdit(
            added: [lena], changed: [ChildEdit(child: renamed(nikos, "Νικόλας"), fields: [.name])]
        )
        #expect(edit.applied(to: [lena]) == [lena])
    }

    @Test("Given a change of one field, when applied, then the other fields keep what is stored")
    func onlyNamedFieldsApply() {
        var mine = lena
        mine.name = "Ελένη"
        mine.skinTone = .dark
        var stored = lena
        stored.gender = .boy
        let edit = FamilyEdit(changed: [ChildEdit(child: mine, fields: [.name])])
        let result = edit.applied(to: [stored])
        #expect(result.first?.name == "Ελένη")
        #expect(result.first?.skinTone == .light)
        #expect(result.first?.gender == .boy)
    }
}
