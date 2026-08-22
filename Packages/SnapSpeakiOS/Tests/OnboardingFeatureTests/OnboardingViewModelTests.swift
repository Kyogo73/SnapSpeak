import Analytics
import Foundation
import HabitKit
import NotificationsKit
import OnboardingFeature
import Persistence
import Testing

@Suite("OnboardingViewModel")
@MainActor
struct OnboardingViewModelTests {
    @Test("1 回目 saveSettings 失敗 → nil・イベント 0 件")
    func skipDoesNotTrackWhenSaveFails() async {
        let store = FakeSettingsStore()
        await store.setFailRemaining(1)
        let analytics = RecordingAnalytics()
        let viewModel = makeViewModel(store: store, analytics: analytics)

        let result = await viewModel.skip()

        #expect(result == nil)
        #expect(analytics.events.isEmpty)
        #expect(viewModel.saveFailed)
        #expect(await store.saved.isEmpty)
    }

    @Test("失敗のあと成功 → onboarding_skipped と onboarding_completed が各 1 件")
    func skipTracksOnceAfterSuccessfulRetry() async {
        let store = FakeSettingsStore()
        await store.setFailRemaining(1)
        let analytics = RecordingAnalytics()
        let viewModel = makeViewModel(store: store, analytics: analytics)

        #expect(await viewModel.skip() == nil)
        #expect(analytics.events.isEmpty)
        #expect(viewModel.saveFailed)

        let retry = await viewModel.skip()
        #expect(retry == false)
        #expect(viewModel.saveFailed == false)
        #expect(analytics.events == [
            .onboardingSkipped(step: "welcome"),
            .onboardingCompleted(goalItems: 10, reminderEnabled: false, skippedGoal: true),
        ])
    }

    @Test("completeGoalStep 失敗 → 再試行でも onboarding_completed は 1 件")
    func completeGoalStepTracksOnceAfterRetry() async {
        let store = FakeSettingsStore()
        await store.setFailRemaining(1)
        let analytics = RecordingAnalytics()
        let viewModel = makeViewModel(store: store, analytics: analytics)
        viewModel.advanceToGoal()

        #expect(await viewModel.completeGoalStep() == nil)
        #expect(analytics.events.isEmpty)
        #expect(viewModel.saveFailed)

        #expect(await viewModel.completeGoalStep() == true)
        #expect(viewModel.saveFailed == false)
        #expect(
            analytics.events == [
                .onboardingCompleted(goalItems: 10, reminderEnabled: true, skippedGoal: false),
            ]
        )
    }

    @Test("保存中の同時 skip は 2 本目を捨てて保存・イベントは 1 組")
    func skipRejectsConcurrentSecondCall() async {
        let store = FakeSettingsStore()
        await store.enableSaveHold()
        let analytics = RecordingAnalytics()
        let viewModel = makeViewModel(store: store, analytics: analytics)

        async let first = viewModel.skip()
        await store.waitUntilSaveStarted()
        let second = await viewModel.skip()
        await store.releaseSave()
        let firstResult = await first

        #expect(firstResult == false)
        #expect(second == nil)
        #expect(await store.saveCount == 1)
        #expect(analytics.events == [
            .onboardingSkipped(step: "welcome"),
            .onboardingCompleted(goalItems: 10, reminderEnabled: false, skippedGoal: true),
        ])
    }

    @Test("リマインダー拒否時は reminderEnabled=false で保存する")
    func deniedReminderSavesDisabled() async {
        let store = FakeSettingsStore()
        let center = FakeOnboardingReminderCenter()
        await center.setAuthorization(.denied)
        let analytics = RecordingAnalytics()
        let scheduler = ReminderScheduler(center: center, analytics: analytics)
        let viewModel = OnboardingViewModel(
            persistence: store,
            scheduler: scheduler,
            analytics: analytics
        )
        viewModel.advanceToGoal()
        viewModel.reminderEnabled = true

        #expect(await viewModel.completeGoalStep() == true)
        #expect(viewModel.reminderEnabled == false)
        let saved = await store.saved.last
        #expect(saved?.reminderEnabled == false)
        #expect(saved?.dailyGoalItems == DailyGoal.standard.itemsPerDay)
        #expect(
            analytics.events == [
                .onboardingCompleted(goalItems: 10, reminderEnabled: false, skippedGoal: false),
            ]
        )
    }

    private func makeViewModel(
        store: FakeSettingsStore,
        analytics: RecordingAnalytics
    ) -> OnboardingViewModel {
        let center = FakeOnboardingReminderCenter()
        let scheduler = ReminderScheduler(center: center, analytics: analytics)
        return OnboardingViewModel(
            persistence: store,
            scheduler: scheduler,
            analytics: analytics
        )
    }
}

actor FakeSettingsStore: SettingsStoring {
    private var failRemaining = 0
    private(set) var saved: [UserSettingsDTO] = []
    private(set) var saveCount = 0
    private var current = UserSettingsDTO.phase1Default
    private var holdSaves = false
    private var saveHasStarted = false
    private var saveStarted: CheckedContinuation<Void, Never>?
    private var saveHold: CheckedContinuation<Void, Never>?

    func setFailRemaining(_ count: Int) {
        failRemaining = count
    }

    func enableSaveHold() {
        holdSaves = true
    }

    func waitUntilSaveStarted() async {
        if saveHasStarted { return }
        await withCheckedContinuation { continuation in
            if saveHasStarted {
                continuation.resume()
            } else {
                saveStarted = continuation
            }
        }
    }

    func releaseSave() {
        saveHold?.resume()
        saveHold = nil
    }

    func loadOrCreateSettings() async throws -> UserSettingsDTO {
        current
    }

    func saveSettings(_ dto: UserSettingsDTO) async throws -> UserSettingsDTO {
        saveCount += 1
        saveHasStarted = true
        saveStarted?.resume()
        saveStarted = nil
        if holdSaves {
            await withCheckedContinuation { continuation in
                saveHold = continuation
            }
        }
        if failRemaining > 0 {
            failRemaining -= 1
            throw FakeSettingsError.saveFailed
        }
        current = dto
        saved.append(dto)
        return dto
    }
}

enum FakeSettingsError: Error {
    case saveFailed
}

actor FakeOnboardingReminderCenter: ReminderCenter {
    private var authorizationState: ReminderAuthorization = .authorized

    func setAuthorization(_ value: ReminderAuthorization) {
        authorizationState = value
    }

    func authorization() async -> ReminderAuthorization {
        authorizationState
    }

    func requestAuthorization() async -> Bool {
        authorizationState == .authorized
    }

    func pendingIds() async -> [String] { [] }
    func add(_: ReminderRequest) async throws {}
    func remove(ids _: [String]) async {}
}

final class RecordingAnalytics: AnalyticsClient, @unchecked Sendable {
    private(set) var events: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) {
        events.append(event)
    }
}
