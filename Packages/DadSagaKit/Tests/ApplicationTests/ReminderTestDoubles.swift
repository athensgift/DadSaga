import Application
import Domain
import Foundation

actor FakeReminderSettings: ReminderSettingsRepository {
    var stored: WeeklyReminder?

    func fetch() async -> WeeklyReminder { stored ?? .default }
    func save(_ reminder: WeeklyReminder) async { stored = reminder }
    func deleteAll() async { stored = nil }
}

actor FakeNotificationScheduler: NotificationScheduler {
    var status: NotificationAuthorization
    let allowsWhenAsked: Bool
    private(set) var pending: [PendingReminder] = []
    private(set) var promptCount = 0
    /// Notes already shown in Notification Center.
    var delivered: [PendingReminder] = []

    init(status: NotificationAuthorization, allowsWhenAsked: Bool = true) {
        self.status = status
        self.allowsWhenAsked = allowsWhenAsked
    }

    func authorization() async -> NotificationAuthorization { status }

    func requestAuthorization() async -> Bool {
        promptCount += 1
        status = allowsWhenAsked ? .allowed : .denied
        return allowsWhenAsked
    }

    func replacePending(with reminders: [PendingReminder]) async { pending = reminders }
    func removeDelivered() async { delivered = [] }

    /// iOS showing the next waiting note.
    func deliverNext() {
        guard !pending.isEmpty else { return }
        delivered.append(pending.removeFirst())
    }
}

struct EchoReminderText: ReminderTextProvider {
    func title() -> String { "This week's quest" }
    func body(questTitle: LocalizedText, childName: String?) -> String {
        [childName, questTitle.en].compactMap(\.self).joined(separator: " · ")
    }
}

/// Allowed; the first time it is asked for pending notifications it takes a while to add them, like a slow run.
actor SlowFirstScheduler: NotificationScheduler {
    private(set) var pending: [PendingReminder] = []
    private(set) var calls = 0

    func authorization() async -> NotificationAuthorization { .allowed }
    func requestAuthorization() async -> Bool { true }

    func replacePending(with reminders: [PendingReminder]) async {
        calls += 1
        if calls == 1 { try? await Task.sleep(for: .milliseconds(200)) }
        pending = reminders
    }

    func removeDelivered() async {}
}

/// Takes a while to save the first change, like a slow disk.
actor SlowFirstSettings: ReminderSettingsRepository {
    private var stored: WeeklyReminder?
    private(set) var calls = 0

    func fetch() async -> WeeklyReminder { stored ?? .default }

    func save(_ reminder: WeeklyReminder) async {
        calls += 1
        if calls == 1 { try? await Task.sleep(for: .milliseconds(200)) }
        stored = reminder
    }

    func deleteAll() async { stored = nil }
}

/// A store that cannot be opened.
struct UnreadableProfiles: ProfileRepository {
    struct Failure: Error {}
    func fetchProfile() async throws -> PlayerProfile? { throw Failure() }
    func create(_ profile: PlayerProfile) async throws { throw Failure() }
    func save(_ edit: FamilyEdit) async throws { throw Failure() }
    func save(_ edit: HeroEdit) async throws { throw Failure() }
    func bringBack(childID: UUID) async throws { throw Failure() }
    func deleteForGood(childID: UUID) async throws -> [String] { throw Failure() }
}

actor FakeSagaOffers: SagaOfferRepository {
    private(set) var answered: Set<String> = []

    func answeredOccasionIDs() async -> Set<String> { answered }
    func markAnswered(_ occasionID: String) async { answered.insert(occasionID) }
    func deleteAll() async { answered = [] }
}
