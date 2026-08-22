import Analytics
import Foundation
import HabitKit
import NotificationsKit
import Persistence
import ReviewFeature

@MainActor
public final class TodayViewModel: ObservableObject {
    public enum TodayState: Equatable {
        case loading
        case ready
        case empty
        case recovery(totalDays: Int, longest: Int)
    }

    @Published public private(set) var state: TodayState = .loading
    @Published public private(set) var snapshot: TodaySnapshot?

    private let persistence: PersistenceActor
    private let todayPlanService: TodayPlanService
    private let scheduler: ReminderScheduler
    private let analytics: any AnalyticsClient
    private var recoveryShown = false

    public init(
        persistence: PersistenceActor,
        todayPlanService: TodayPlanService,
        scheduler: ReminderScheduler,
        analytics: any AnalyticsClient
    ) {
        self.persistence = persistence
        self.todayPlanService = todayPlanService
        self.scheduler = scheduler
        self.analytics = analytics
    }

    public func refresh(now: Date = Date()) async {
        let settings = (try? await persistence.loadOrCreateSettings()) ?? UserSettingsDTO.phase1Default
        let timeZone = TimeZone.current
        let goal = DailyGoal(itemsPerDay: settings.dailyGoalItems)
        do {
            let today = try await todayPlanService.makeToday(
                now: now,
                timeZone: timeZone,
                goal: goal,
                policy: .standard
            )
            trackProgressEvents(previous: snapshot, next: today)
            let broken = settings.lastKnownStreakDays > 0 && today.streak.currentStreakDays == 0
            if broken && !recoveryShown {
                recoveryShown = true
                state = .recovery(
                    totalDays: today.streak.totalStudyDays,
                    longest: today.streak.longestStreakDays
                )
                analytics.track(
                    .streakBroken(lengthBand: Quantization.streakBand(days: settings.lastKnownStreakDays))
                )
                // lastKnown は閉じるまで残し、再 refresh で回復カードが消えないようにする。
            } else if case .recovery = state, broken {
                // keep recovery until dismiss
            } else if !today.hasCourses {
                state = .empty
                await persistLastKnown(today.streak.currentStreakDays, base: settings)
            } else {
                state = .ready
                await persistLastKnown(today.streak.currentStreakDays, base: settings)
            }
            snapshot = today
            await syncReminders(settings: settings, streak: today.streak, now: now, timeZone: timeZone)
        } catch {
            state = .empty
        }
    }

    public func dismissRecovery() {
        recoveryShown = true
        if snapshot?.hasCourses == false {
            state = .empty
        } else {
            state = .ready
        }
        Task {
            let base = (try? await persistence.loadOrCreateSettings()) ?? UserSettingsDTO.phase1Default
            await persistLastKnown(snapshot?.streak.currentStreakDays ?? 0, base: base)
        }
    }

    private func trackProgressEvents(previous: TodaySnapshot?, next: TodaySnapshot) {
        guard let previous else { return }
        if !previous.streak.studiedToday && next.streak.studiedToday {
            analytics.track(
                .streakDayRecorded(streakBand: Quantization.streakBand(days: next.streak.currentStreakDays))
            )
        }
        if !previous.goal.isMet && next.goal.isMet {
            analytics.track(.goalMet(goalItems: next.goal.goalItems))
        }
    }

    private func persistLastKnown(_ days: Int, base: UserSettingsDTO) async {
        var dto = base
        dto.lastKnownStreakDays = days
        _ = try? await persistence.saveSettings(dto)
    }

    private func syncReminders(
        settings: UserSettingsDTO,
        streak: StreakSnapshot,
        now: Date,
        timeZone: TimeZone
    ) async {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let reminder = ReminderPlanner.plan(
            settings: ReminderSettings(
                isEnabled: settings.reminderEnabled,
                hour: settings.reminderHour ?? 21,
                minute: settings.reminderMinute
            ),
            streak: streak,
            now: now,
            calendar: calendar
        )
        await scheduler.sync(plan: reminder, goalItems: settings.dailyGoalItems)
    }
}
