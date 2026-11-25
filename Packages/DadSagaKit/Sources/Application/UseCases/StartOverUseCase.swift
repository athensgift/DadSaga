import Foundation

/// Deletes the whole saga (profile, progress, wardrobe, photos, reminder and its pending notifications, and the answers
/// to the film offers) so the app starts again from onboarding. Only the dad's own choice in Settings runs it (ADR-0030).
public protocol StartOverUseCase: Sendable {
    func execute(on date: Date) async throws
}

public struct DefaultStartOverUseCase: StartOverUseCase {
    private let wholeSaga: any WholeSagaRepository
    private let photoStore: any PhotoStore
    private let reminderSettings: any ReminderSettingsRepository
    private let sagaOffers: any SagaOfferRepository
    private let renewReminders: any RenewWeeklyRemindersUseCase

    public init(
        wholeSaga: any WholeSagaRepository,
        photoStore: any PhotoStore,
        reminderSettings: any ReminderSettingsRepository,
        sagaOffers: any SagaOfferRepository,
        renewReminders: any RenewWeeklyRemindersUseCase
    ) {
        self.wholeSaga = wholeSaga
        self.photoStore = photoStore
        self.reminderSettings = reminderSettings
        self.sagaOffers = sagaOffers
        self.renewReminders = renewReminders
    }

    /// The store goes first, in one write. If it fails nothing else is touched, so the saga is still whole.
    public func execute(on date: Date) async throws {
        try await wholeSaga.eraseAll()
        await reminderSettings.deleteAll()
        // The answers were about the saga that is gone (ADR-0036 §7).
        await sagaOffers.deleteAll()
        // Finds the reminder off, so what is waiting goes too.
        await renewReminders.execute(on: date)
        await photoStore.deleteAll()
    }
}
