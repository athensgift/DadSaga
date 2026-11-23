import Application
import Domain
import Foundation
import Localization
import Observation

/// Presenter for "My family": add, edit or remove children after onboarding, mark a child born, and the partner
/// answer. The dad's look is on "Your hero".
/// Children keep their ids, so progress with them stays linked; removing a child never takes XP away (ADR-0006).
@MainActor
@Observable
public final class FamilyViewModel {
    public private(set) var state: FamilyViewState = .loading
    public var family = FamilyDraft(children: [])
    public private(set) var isSaving = false
    public private(set) var errorMessage: String?
    /// A child cannot be born in the future.
    public let latestBirthDate: Date

    public var canSave: Bool { family.isComplete && !isSaving }
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
    private let locale: Locale
    /// The zone the date pickers draw in, and the one "today" is read in.
    public let timeZone: TimeZone
    private let onSaved: @MainActor () -> Void

    public init(
        getProfile: any GetProfileUseCase,
        updateFamily: any UpdateFamilyUseCase,
        locale: Locale = .current,
        now: Date = .now,
        timeZone: TimeZone = .autoupdatingCurrent,
        onSaved: @escaping @MainActor () -> Void
    ) {
        self.getProfile = getProfile
        self.updateFamily = updateFamily
        self.locale = locale
        self.timeZone = timeZone
        self.onSaved = onSaved
        latestBirthDate = now
    }

    public func onAppear() async {
        guard state == .loading else { return }
        do {
            guard let profile = try await getProfile.execute() else {
                state = .failed(message: strings.text("No profile found."))
                return
            }
            family = FamilyDraft(profile, today: CalendarDay(latestBirthDate, in: timeZone))
            stored = family
            state = .loaded(makeContent())
        } catch {
            state = .failed(message: strings.text("Your family failed to load."))
        }
    }

    public func addChild() {
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
            try await updateFamily.execute(edit, on: latestBirthDate)
            stored = saving
            if family == saving { onSaved() }
        } catch {
            errorMessage = strings.text("Couldn't save. Please try again.")
        }
    }

    private func makeContent() -> FamilyContent {
        FamilyContent(
            title: strings.text("My family"),
            childEditor: ChildEditorLabels.make(locale: locale),
            partner: PartnerRowLabels.make(locale: locale),
            saveTitle: strings.text("Save"),
            unsaved: JournalLabels(locale: locale),
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
    public let footnote: String
}
