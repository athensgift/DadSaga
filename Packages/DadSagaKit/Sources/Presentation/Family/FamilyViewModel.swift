import Application
import Domain
import Foundation
import Localization
import Observation

/// Presenter for "My family": add, edit or remove children after onboarding, mark a child born, and the partner
/// answer. The dad's look is on "Your hero".
/// Children keep their ids, so progress with them stays linked. Removing a child keeps them, with every entry, to bring
/// back; removing and bringing back change no one's standing (ADR-0006, ADR-0065 §4). Deleting a removed child for good
/// is the one way a child and their entries go, asked first in calm words that show no counts.
/// Removing is a change saved with Save; bringing back and deleting for good are acts saved at once, which keep the
/// dad's unsaved changes.
@MainActor
@Observable
public final class FamilyViewModel {
    public private(set) var state: FamilyViewState = .loading
    public var family = FamilyDraft(children: [])
    public private(set) var isSaving = false
    public private(set) var errorMessage: String?
    /// The children removed from the family, to bring back or delete for good. Empty: the section isn't shown.
    public private(set) var removedChildren: [RemovedChildRow] = []
    /// Asked before a removed child is deleted for good.
    public private(set) var deletion: DeletionPrompt?
    /// A child cannot be born in the future: now, as last read.
    public private(set) var latestBirthDate: Date

    public var canSave: Bool { family.isComplete && !isSaving }
    /// Bringing back is adding (ADR-0065 §4): the family on screen and the stored one both have room.
    public var canBringBack: Bool { !isSaving && !isFamilyFull }
    /// Four in the family: "Bring back" gives way to a line that says so.
    public var isFamilyFull: Bool {
        !family.canAddChild || (stored?.children.count ?? 0) >= PlayerProfile.maxChildren
    }
    /// The way back to Settings. The screen draws its own, so it can ask first when leaving would lose changes.
    public var backTitle: String { strings.text("Settings") }

    /// The family as last loaded or saved: leaving with anything else would lose the dad's changes.
    private var stored: FamilyDraft?

    /// Something changed and isn't saved yet, so leaving asks first (`UnsavedChangesGuard`).
    public var hasUnsavedChanges: Bool {
        guard let stored else { return false }
        return family != stored
    }

    private let getProfile: any GetProfileUseCase
    private let updateFamily: any UpdateFamilyUseCase
    private let bringBackChild: any BringBackChildUseCase
    private let deleteChildForGood: any DeleteChildForGoodUseCase
    private let locale: Locale
    private let now: @Sendable () -> Date
    /// The zone the date pickers draw in, and the one "today" is read in.
    public let timeZone: TimeZone
    private let onSaved: @MainActor () -> Void

    public init(
        getProfile: any GetProfileUseCase,
        updateFamily: any UpdateFamilyUseCase,
        bringBack: any BringBackChildUseCase,
        deleteForGood: any DeleteChildForGoodUseCase,
        locale: Locale = .current,
        now: @escaping @Sendable () -> Date = Date.init,
        timeZone: TimeZone = .autoupdatingCurrent,
        onSaved: @escaping @MainActor () -> Void
    ) {
        self.getProfile = getProfile
        self.updateFamily = updateFamily
        bringBackChild = bringBack
        deleteChildForGood = deleteForGood
        self.locale = locale
        self.timeZone = timeZone
        self.onSaved = onSaved
        self.now = now
        latestBirthDate = now()
    }

    public func onAppear() async {
        guard state == .loading else { return }
        do {
            guard let profile = try await getProfile.execute() else {
                state = .failed(message: strings.text("No profile found."))
                return
            }
            family = FamilyDraft(profile, today: today)
            stored = family
            removedChildren = rows(profile.removedChildren)
            state = .loaded(makeContent())
        } catch {
            state = .failed(message: strings.text("Your family failed to load."))
        }
    }

    /// Back in the app, perhaps a day later: a child can be born today.
    public func appBecameActive() {
        latestBirthDate = now()
    }

    public func addChild() {
        latestBirthDate = now()
        family.addChild(birthDay: CalendarDay(latestBirthDate, in: timeZone))
    }

    public func removeChild(id: UUID) {
        family.removeChild(id: id)
    }

    /// Saves what changed since the family was loaded or last saved, never the whole family, so a child or field the
    /// dad didn't touch keeps what is stored (ADR-0065 §4). An edit made while it saves stays unsaved, and the screen
    /// stays open to show it. The last error goes as the save starts, so the same error again is read out again.
    public func save() async {
        guard canSave, let shown = stored else { return }
        isSaving = true
        defer { isSaving = false }
        errorMessage = nil
        let saving = family
        do {
            let edit = FamilyEdit(
                shown: shown.children.map(\.child), hasPartner: shown.hasPartner,
                edited: saving.children.map(\.child), hasPartner: saving.hasPartner
            )
            try await updateFamily.execute(edit, on: now())
            stored = saving
            if family == saving {
                onSaved()
            } else if !edit.removedIDs.isEmpty, let profile = try? await getProfile.execute() {
                // The page stays open: a child just removed joins the removed ones.
                removedChildren = rows(profile.removedChildren)
            }
        } catch {
            errorMessage = strings.text("Couldn't save. Please try again.")
        }
    }

    /// Brings a removed child back at once, in their place; the dad's unsaved changes stay unsaved.
    public func bringBack(id: UUID) async {
        guard canBringBack else { return }
        await act(on: id, failure: strings.text("Couldn't save. Please try again.")) {
            try await bringBackChild.execute(childID: id)
        }
    }

    public func requestDeletion(id: UUID) {
        guard !isSaving, let row = removedChildren.first(where: { $0.id == id }) else { return }
        errorMessage = nil
        // The name only: no counts of what goes (ADR-0065 §4).
        deletion = DeletionPrompt(
            id: id,
            title: strings.text("Delete \(row.name) for good?"),
            message: strings.text(
                "\(row.name) and everything recorded with them, photos included, will be deleted. This can't be undone."
            ),
            confirmTitle: strings.text("Delete for good"),
            cancelTitle: strings.text("Cancel")
        )
    }

    public func cancelDeletion() {
        deletion = nil
    }

    /// Takes the id rather than reading `deletion`: the dialog clears its binding before the button's action runs.
    public func confirmDeletion(id: UUID) async {
        deletion = nil
        guard !isSaving else { return }
        await act(on: id, failure: strings.text("Couldn't delete. Please try again.")) {
            try await deleteChildForGood.execute(childID: id)
        }
    }

    /// Runs an act on the removed child `id` that saves at once, then reads the family again and puts the dad's unsaved
    /// changes back on it, so a brought-back child shows in their place and a pending rename is still pending. Only the
    /// act's own failure says it failed: once it is done, a failed read takes the row away and says the family didn't
    /// load, rather than offer an act that already happened.
    private func act(on id: UUID, failure: String, _ work: () async throws -> Void) async {
        isSaving = true
        defer { isSaving = false }
        errorMessage = nil
        do {
            try await work()
        } catch {
            errorMessage = failure
            return
        }
        do {
            guard let profile = try await getProfile.execute() else { return }
            rebase(on: profile)
        } catch {
            removedChildren.removeAll { $0.id == id }
            errorMessage = strings.text("Your family failed to load.")
        }
    }

    /// Read after the last `await`, so an edit made while the act ran is kept.
    private func rebase(on profile: PlayerProfile) {
        guard let shown = stored else { return }
        let pending = FamilyEdit(
            shown: shown.children.map(\.child), hasPartner: shown.hasPartner,
            edited: family.children.map(\.child), hasPartner: family.hasPartner
        )
        // A draft the dad already has keeps what only the draft holds, such as the picker's day of a child not born.
        let drafts = family.children + shown.children
        let today = today
        func draft(_ child: Child) -> ChildDraft {
            drafts.first { $0.id == child.id && $0.child == child } ?? ChildDraft(child, today: today)
        }
        var newStored = shown
        newStored.children = profile.children.map(draft)
        newStored.hasPartner = profile.hasPartner
        family.children = pending.applied(to: profile.children).map(draft)
        family.hasPartner = pending.hasPartner ?? profile.hasPartner
        stored = newStored
        removedChildren = rows(profile.removedChildren)
    }

    private func rows(_ children: [Child]) -> [RemovedChildRow] {
        children.map { child in
            RemovedChildRow(
                id: child.id,
                name: child.name,
                bringBackLabel: strings.text("Bring back \(child.name)"),
                deleteLabel: strings.text("Delete \(child.name) for good")
            )
        }
    }

    private var today: CalendarDay { CalendarDay(now(), in: timeZone) }

    private func makeContent() -> FamilyContent {
        FamilyContent(
            title: strings.text("My family"),
            childEditor: ChildEditorLabels.make(locale: locale),
            partner: PartnerRowLabels.make(locale: locale),
            saveTitle: strings.text("Save"),
            unsaved: JournalLabels(locale: locale),
            removed: RemovedChildrenLabels(
                title: strings.text("Removed from the family"),
                line: strings.text("Kept with everything recorded with them."),
                bringBack: strings.text("Bring back"),
                deleteForGood: strings.text("Delete for good"),
                full: strings.text("The family has room for four children. To bring one back, remove another first.")
            ),
            footnote: strings.text("If you remove a child, everything you earned together stays.")
        )
    }

    private var strings: Strings { Strings(locale: locale) }
}

public enum FamilyViewState: Equatable, Sendable {
    case loading
    case loaded(FamilyContent)
    case failed(message: String)
}

public struct FamilyContent: Equatable, Sendable {
    public let title: String
    public let childEditor: ChildEditorLabels
    public let partner: PartnerRowLabels
    public let saveTitle: String
    /// "Discard the changes you just made?" and its answers.
    public let unsaved: JournalLabels
    public let removed: RemovedChildrenLabels
    public let footnote: String
}

/// The section of the children removed from the family.
public struct RemovedChildrenLabels: Equatable, Sendable {
    public let title: String
    public let line: String
    public let bringBack: String
    public let deleteForGood: String
    /// Instead of "Bring back" while the family has four.
    public let full: String
}

/// A child removed from the family: the name only, no figure, dates or counts.
public struct RemovedChildRow: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    /// For VoiceOver, with the name.
    public let bringBackLabel: String
    public let deleteLabel: String
}
