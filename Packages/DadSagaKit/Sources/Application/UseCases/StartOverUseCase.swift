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
    private let schedule: any ScheduleWeeklyRemindersUseCase
    private let notificationScheduler: any NotificationScheduler

    /// - Parameter schedule: the app's one reschedule, so a run already under way cannot put notifications back after
    ///   this one cleared them (ADR-0024).
    public init(
        wholeSaga: any WholeSagaRepository,
        photoStore: any PhotoStore,
        reminderSettings: any ReminderSettingsRepository,
        sagaOffers: any SagaOfferRepository,
        schedule: any ScheduleWeeklyRemindersUseCase,
        notificationScheduler: any NotificationScheduler
    ) {
        self.wholeSaga = wholeSaga
        self.photoStore = photoStore
        self.reminderSettings = reminderSettings
        self.sagaOffers = sagaOffers
        self.schedule = schedule
        self.notificationScheduler = notificationScheduler
    }

    /// The store goes first, in one write. If it fails nothing else is touched, so the saga is still whole.
    public func execute(on date: Date) async throws {
        try await wholeSaga.eraseAll()
        await reminderSettings.deleteAll()
        // The answers were about the saga that is gone (ADR-0036 §7).
        await sagaOffers.deleteAll()
        // Finds the reminder off and clears what is waiting.
        await schedule.execute(on: date)
        // Notes already shown name the children and link to them.
        await notificationScheduler.removeDelivered()
        await photoStore.deleteAll()
    }
}
