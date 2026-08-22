import Analytics
import Foundation
import HabitKit
import NotificationsKit
import Testing

@Suite("ReminderScheduler")
struct ReminderSchedulerTests {
    @Test("認可なしでは登録しない")
    func deniedAuthorizationDoesNotAdd() async {
        let center = FakeReminderCenter()
        await center.setAuthorization(.denied)
        let analytics = RecordingAnalytics()
        let scheduler = ReminderScheduler(center: center, analytics: analytics)
        await scheduler.sync(plan: [Self.sampleReminder()], goalItems: 10)
        #expect(await center.added.isEmpty)
        #expect(analytics.events.isEmpty)
    }

    @Test("未決定なら request し、許可後は登録できる")
    func requestThenAuthorizedAdds() async {
        let center = FakeReminderCenter()
        await center.setAuthorization(.notDetermined)
        await center.setRequestResult(true)
        let analytics = RecordingAnalytics()
        let scheduler = ReminderScheduler(center: center, analytics: analytics)
        let granted = await scheduler.requestAuthorizationIfNeeded()
        #expect(granted)
        await scheduler.sync(plan: [Self.sampleReminder()], goalItems: 10)
        #expect(await center.added.map(\.id) == ["reminder-2026-08-21"])
        #expect(analytics.events == [.reminderScheduled(kind: "daily")])
    }

    @Test("同じ id の再同期は pending を消して入れ直す")
    func resyncIsIdempotent() async {
        let center = FakeReminderCenter()
        let analytics = RecordingAnalytics()
        let scheduler = ReminderScheduler(center: center, analytics: analytics)
        await scheduler.sync(plan: [Self.sampleReminder()], goalItems: 10)
        await scheduler.sync(plan: [Self.sampleReminder()], goalItems: 10)
        #expect(await center.pending == ["reminder-2026-08-21"])
        #expect(await center.removed.contains(["reminder-2026-08-21"]))
    }

    @Test("登録失敗では reminder_scheduled を出さない")
    func addFailureDoesNotTrack() async {
        let center = FakeReminderCenter()
        await center.setAddShouldFail(true)
        let analytics = RecordingAnalytics()
        let scheduler = ReminderScheduler(center: center, analytics: analytics)
        await scheduler.sync(plan: [Self.sampleReminder()], goalItems: 10)
        #expect(analytics.events.isEmpty)
    }

    @Test("古い ON 同期は OFF の後に通知を足さない")
    func staleSyncDoesNotReaddAfterOff() async {
        let center = FakeReminderCenter()
        await center.setAddDelayNanoseconds(80_000_000)
        let analytics = RecordingAnalytics()
        let scheduler = ReminderScheduler(center: center, analytics: analytics)
        async let first: Void = scheduler.sync(plan: [Self.sampleReminder()], goalItems: 10)
        try? await Task.sleep(nanoseconds: 10_000_000)
        await scheduler.sync(plan: [], goalItems: 10)
        await first
        #expect(await center.pending.isEmpty)
        #expect(analytics.events.isEmpty)
    }

    private static func sampleReminder() -> PlannedReminder {
        PlannedReminder(
            id: "reminder-2026-08-21",
            fireAt: Date(timeIntervalSince1970: 1_777_000_000),
            kind: .daily,
            streakDays: 0
        )
    }
}

actor FakeReminderCenter: ReminderCenter {
    private var authorizationState: ReminderAuthorization = .authorized
    private var requestResult = true
    private var addShouldFail = false
    private var addDelayNanoseconds: UInt64 = 0
    private(set) var added: [ReminderRequest] = []
    private(set) var pending: [String] = []
    private(set) var removed: [[String]] = []

    func setAuthorization(_ value: ReminderAuthorization) {
        authorizationState = value
    }

    func setRequestResult(_ value: Bool) {
        requestResult = value
    }

    func setAddShouldFail(_ value: Bool) {
        addShouldFail = value
    }

    func setAddDelayNanoseconds(_ value: UInt64) {
        addDelayNanoseconds = value
    }

    func authorization() async -> ReminderAuthorization {
        authorizationState
    }

    func requestAuthorization() async -> Bool {
        if requestResult {
            authorizationState = .authorized
        } else {
            authorizationState = .denied
        }
        return requestResult
    }

    func pendingIds() async -> [String] {
        pending
    }

    func add(_ request: ReminderRequest) async throws {
        if addDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: addDelayNanoseconds)
        }
        if addShouldFail {
            throw FakeReminderError.addFailed
        }
        added.append(request)
        pending.append(request.id)
    }

    func remove(ids: [String]) async {
        removed.append(ids)
        pending.removeAll { ids.contains($0) }
    }
}

enum FakeReminderError: Error {
    case addFailed
}

final class RecordingAnalytics: AnalyticsClient, @unchecked Sendable {
    private(set) var events: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) {
        events.append(event)
    }
}
