import Analytics
import Foundation
import HabitKit
import NotificationsKit
import Persistence

@MainActor
public final class OnboardingViewModel: ObservableObject {
    public enum Step: Equatable {
        case welcome
        case goal
    }

    @Published public private(set) var step: Step = .welcome
    @Published public var selectedGoal: DailyGoal = .standard
    @Published public var reminderEnabled = true
    @Published public var reminderTime = DateComponents(hour: 21, minute: 0)

    private let persistence: PersistenceActor
    private let scheduler: ReminderScheduler
    private let analytics: any AnalyticsClient
    private var didTrackStart = false

    public init(
        persistence: PersistenceActor,
        scheduler: ReminderScheduler,
        analytics: any AnalyticsClient
    ) {
        self.persistence = persistence
        self.scheduler = scheduler
        self.analytics = analytics
    }

    public func appear() {
        guard !didTrackStart else { return }
        didTrackStart = true
        analytics.track(.onboardingStarted)
    }

    public func advanceToGoal() {
        step = .goal
    }

    /// 設定保存 → reminderEnabled なら requestAuthorizationIfNeeded()（拒否なら
    /// reminderEnabled=false で保存し直す）→ onboardingCompletedAt = now →
    /// onboarding_completed を track。
    public func completeGoalStep() async -> Bool {
        var enabled = reminderEnabled
        if enabled {
            let granted = await scheduler.requestAuthorizationIfNeeded()
            if !granted {
                enabled = false
                reminderEnabled = false
            }
        }
        await persist(goal: selectedGoal, reminderEnabled: enabled, skippedGoal: false)
        analytics.track(
            .onboardingCompleted(
                goalItems: selectedGoal.itemsPerDay,
                reminderEnabled: enabled,
                skippedGoal: false
            )
        )
        return true
    }

    /// step に応じ既定値で保存して完了扱い。onboarding_skipped(step:) を track。
    public func skip() async -> Bool {
        let fromWelcome = step == .welcome
        analytics.track(.onboardingSkipped(step: fromWelcome ? "welcome" : "goal"))
        await persist(goal: .standard, reminderEnabled: false, skippedGoal: true)
        analytics.track(
            .onboardingCompleted(
                goalItems: DailyGoal.standard.itemsPerDay,
                reminderEnabled: false,
                skippedGoal: true
            )
        )
        return !fromWelcome
    }

    private func persist(goal: DailyGoal, reminderEnabled: Bool, skippedGoal: Bool) async {
        var dto = (try? await persistence.loadOrCreateSettings()) ?? UserSettingsDTO.phase1Default
        dto.dailyGoalItems = goal.itemsPerDay
        dto.reminderEnabled = reminderEnabled
        if !skippedGoal {
            dto.reminderHour = reminderTime.hour ?? 21
            dto.reminderMinute = reminderTime.minute ?? 0
        }
        dto.onboardingCompletedAt = Date()
        _ = try? await persistence.saveSettings(dto)
    }
}
