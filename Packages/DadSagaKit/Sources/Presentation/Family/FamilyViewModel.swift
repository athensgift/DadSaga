import Application
import Domain
import Foundation
import Localization
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
                state = .failed(message: strings.text("No profile found."))
                return
            }
            heroClassID = profile.heroClassID
            family = FamilyDraft(profile)
            state = .loaded(makeContent())
        } catch {
            state = .failed(message: strings.text("Your family failed to load."))
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
            errorMessage = strings.text("Couldn't save. Please try again.")
        }
    }

    private func makeContent() -> FamilyContent {
        FamilyContent(
            title: strings.text("My family"),
            childEditor: ChildEditorLabels.make(locale: locale),
            dadSkinToneLabel: strings.text("Your skin tone"),
            saveTitle: strings.text("Save"),
            footnote: strings.text("If you remove a child, everything you earned together stays.")
        )
    }

    private var strings: Strings { Strings(locale: locale) }
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
