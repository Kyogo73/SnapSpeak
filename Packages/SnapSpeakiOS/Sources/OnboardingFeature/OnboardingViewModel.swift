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
    @Published public private(set) var isSaving = false
    @Published public private(set) var saveFailed = false

    private let persistence: any SettingsStoring
    private let scheduler: ReminderScheduler
    private let analytics: any AnalyticsClient
    private var didTrackStart = false

    public init(
        persistence: any SettingsStoring,
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
    /// 保存成功時のみ `startFirstLesson` を返す。失敗時は `nil`（cover は閉じない）。
    public func completeGoalStep() async -> Bool? {
        guard !isSaving else { return nil }
        isSaving = true
        defer { isSaving = false }
        var enabled = reminderEnabled
        if enabled {
            let granted = await scheduler.requestAuthorizationIfNeeded()
            if !granted {
                enabled = false
                reminderEnabled = false
            }
        }
        do {
            try await persist(goal: selectedGoal, reminderEnabled: enabled, skippedGoal: false)
        } catch {
            return nil
        }
        analytics.track(
            .onboardingCompleted(
                goalItems: selectedGoal.itemsPerDay,
                reminderEnabled: enabled,
                skippedGoal: false
            )
        )
        return true
    }

    /// 保存成功時のみ `startFirstLesson` を返す。失敗時は `nil`。
    public func skip() async -> Bool? {
        guard !isSaving else { return nil }
        isSaving = true
        defer { isSaving = false }
        let fromWelcome = step == .welcome
        do {
            try await persist(goal: .standard, reminderEnabled: false, skippedGoal: true)
        } catch {
            return nil
        }
        analytics.track(.onboardingSkipped(step: fromWelcome ? "welcome" : "goal"))
        analytics.track(
            .onboardingCompleted(
                goalItems: DailyGoal.standard.itemsPerDay,
                reminderEnabled: false,
                skippedGoal: true
            )
        )
        return !fromWelcome
    }

    private func persist(goal: DailyGoal, reminderEnabled: Bool, skippedGoal: Bool) async throws {
        var dto = (try? await persistence.loadOrCreateSettings()) ?? UserSettingsDTO.phase1Default
        dto.dailyGoalItems = goal.itemsPerDay
        dto.reminderEnabled = reminderEnabled
        if !skippedGoal {
            dto.reminderHour = reminderTime.hour ?? 21
            dto.reminderMinute = reminderTime.minute ?? 0
        }
        dto.onboardingCompletedAt = Date()
        saveFailed = false
        do {
            _ = try await persistence.saveSettings(dto)
        } catch {
            saveFailed = true
            throw error
        }
    }
}
