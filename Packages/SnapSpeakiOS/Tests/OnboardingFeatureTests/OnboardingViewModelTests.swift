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
    private var current = UserSettingsDTO.phase1Default

    func setFailRemaining(_ count: Int) {
        failRemaining = count
    }

    func loadOrCreateSettings() async throws -> UserSettingsDTO {
        current
    }

    func saveSettings(_ dto: UserSettingsDTO) async throws -> UserSettingsDTO {
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
