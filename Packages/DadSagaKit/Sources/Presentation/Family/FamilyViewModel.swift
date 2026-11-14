import Application
import Domain
import Foundation
import Observation

/// Presenter for "My family": add, edit or remove children, and change the dad's skin tone, after onboarding.
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

    private let getProfile: any GetProfileUseCase
    private let saveProfile: any SaveProfileUseCase
    private let locale: Locale
    private let onSaved: @MainActor () -> Void
    private var heroClassID = ""

    public init(
        getProfile: any GetProfileUseCase,
        saveProfile: any SaveProfileUseCase,
        locale: Locale = .current,
        now: Date = .now,
        onSaved: @escaping @MainActor () -> Void
    ) {
        self.getProfile = getProfile
        self.saveProfile = saveProfile
        self.locale = locale
        self.onSaved = onSaved
        latestBirthDate = now
    }

    public func onAppear() async {
        guard state == .loading else { return }
        do {
            guard let profile = try await getProfile.execute() else {
                state = .failed(message: text(el: "Δεν βρέθηκε προφίλ.", en: "No profile found."))
                return
            }
            heroClassID = profile.heroClassID
            family = FamilyDraft(profile)
            state = .loaded(makeContent())
        } catch {
            state = .failed(message: text(el: "Η οικογένεια δεν φόρτωσε.", en: "Your family failed to load."))
        }
    }

    public func addChild() {
        family.addChild(birthDate: latestBirthDate)
    }

    public func removeChild(id: UUID) {
        family.removeChild(id: id)
    }

    public func save() async {
        guard canSave else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let profile = PlayerProfile(
                children: family.children.map(\.child),
                heroClassID: heroClassID,
                dadSkinTone: family.dadSkinTone.domain
            )
            try await saveProfile.execute(profile, on: latestBirthDate)
            errorMessage = nil
            onSaved()
        } catch {
            errorMessage = text(el: "Δεν αποθηκεύτηκε. Δοκίμασε ξανά.", en: "Couldn't save. Please try again.")
        }
    }

    private func makeContent() -> FamilyContent {
        FamilyContent(
            title: text(el: "Η οικογένειά μου", en: "My family"),
            childEditor: ChildEditorLabels.make(locale: locale),
            dadSkinToneLabel: text(el: "Η απόχρωσή σου", en: "Your skin tone"),
            saveTitle: text(el: "Αποθήκευση", en: "Save"),
            footnote: text(
                el: "Αν αφαιρέσεις ένα παιδί, ό,τι κέρδισες μαζί του μένει.",
                en: "If you remove a child, everything you earned together stays."
            )
        )
    }

    private func text(el: String, en: String) -> String {
        LocalizedText(el: el, en: en).resolved(for: locale)
    }
}

/// Identified by object, so home can present it with `sheet(item:)`.
extension FamilyViewModel: Identifiable {}

public enum FamilyViewState: Equatable, Sendable {
    case loading
    case loaded(FamilyContent)
    case failed(message: String)
}

public struct FamilyContent: Equatable, Sendable {
    public let title: String
    public let childEditor: ChildEditorLabels
    public let dadSkinToneLabel: String
    public let saveTitle: String
    public let footnote: String
}
