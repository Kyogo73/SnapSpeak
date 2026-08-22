import Analytics
import ContentCore
import Foundation
import HabitKit
import LanguageKit
import NotificationsKit
import Persistence
import ReviewFeature
import SpeechKit
import SRSKit

@MainActor
public final class TodayViewModel: ObservableObject {
    public enum TodayState: Equatable {
        case loading
        case ready
        case empty
        case failed
        case recovery(totalDays: Int, longest: Int)
    }

    @Published public private(set) var state: TodayState = .loading
    @Published public private(set) var snapshot: TodaySnapshot?
    @Published public private(set) var asrDegraded = false
    @Published public private(set) var continueLesson: LessonCoordinate?

    private let persistence: PersistenceActor
    private let todayPlanService: TodayPlanService
    private let scheduler: ReminderScheduler
    private let analytics: any AnalyticsClient
    private var refreshGeneration = 0

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
        refreshGeneration += 1
        let generation = refreshGeneration
        state = snapshot == nil ? .loading : state
        let settings = (try? await persistence.loadOrCreateSettings()) ?? UserSettingsDTO.phase1Default
        guard generation == refreshGeneration else { return }
        let timeZone = TimeZone.current
        let goal = DailyGoal(itemsPerDay: settings.dailyGoalItems)
        do {
            let today = try await todayPlanService.makeToday(
                now: now,
                timeZone: timeZone,
                goal: goal,
                policy: .standard
            )
            guard generation == refreshGeneration else { return }
            asrDegraded = Self.speechIsDegraded(settings: settings)
            continueLesson = await resolveContinueLesson(settings: settings)
            try await applyHabitState(
                today: today,
                settings: settings,
                now: now,
                timeZone: timeZone
            )
            guard generation == refreshGeneration else { return }
            snapshot = today
            await syncReminders(settings: settings, streak: today.streak, now: now, timeZone: timeZone)
        } catch {
            guard generation == refreshGeneration else { return }
            state = .failed
        }
    }

    public func dismissRecovery() {
        Task {
            let settings = (try? await persistence.loadOrCreateSettings()) ?? UserSettingsDTO.phase1Default
            try? await persistence.markRecoveryDismissed(fromStreak: settings.lastKnownStreakDays)
            try? await persistence.updateLastKnownStreakDays(snapshot?.streak.currentStreakDays ?? 0)
            if snapshot?.hasCourses == false {
                state = .empty
            } else if snapshot != nil {
                state = .ready
            }
        }
    }

    public func regeneratePlanThenStart() async -> Bool {
        await refresh()
        return snapshot?.plan.isEmpty == false
    }

    private func applyHabitState(
        today: TodaySnapshot,
        settings: UserSettingsDTO,
        now: Date,
        timeZone: TimeZone
    ) async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let studyDayStart = StudyDay.studyDay(of: now, calendar: calendar)
        let broken = HabitAnalytics.shouldRecordStreakBroken(
            streakDays: today.streak.currentStreakDays,
            lastKnownStreakDays: settings.lastKnownStreakDays,
            studyDayStart: studyDayStart,
            brokenRecordedDayStart: settings.habitBrokenRecordedDayStart
        )
        let dismissedThisBreak = settings.recoveryDismissedFromStreak == settings.lastKnownStreakDays
            && settings.lastKnownStreakDays > 0
        if broken && !dismissedThisBreak {
            state = .recovery(
                totalDays: today.streak.totalStudyDays,
                longest: today.streak.longestStreakDays
            )
            analytics.track(
                .streakBroken(lengthBand: Quantization.streakBand(days: settings.lastKnownStreakDays))
            )
            var markers = settings.habitMarkers
            markers.brokenRecordedDayStart = studyDayStart
            try await persistence.updateHabitMarkers(markers)
        } else if case .recovery = state, today.streak.currentStreakDays == 0, !dismissedThisBreak {
            // keep recovery until dismiss
        } else if !today.hasCourses {
            state = .empty
            try await persistence.updateLastKnownStreakDays(today.streak.currentStreakDays)
        } else {
            state = .ready
            try await persistence.updateLastKnownStreakDays(today.streak.currentStreakDays)
        }
    }

    private func resolveContinueLesson(settings: UserSettingsDTO) async -> LessonCoordinate? {
        if let courseId = settings.lastOpenedCourseId,
           let lessonId = settings.lastOpenedLessonId,
           let itemId = settings.lastOpenedItemId,
           let mode = settings.lastOpenedMode.flatMap(LessonMode.init(rawValue:)) {
            return LessonCoordinate(courseId: courseId, lessonId: lessonId, itemId: itemId, mode: mode)
        }
        guard let attempt = try? await persistence.latestAttempt(),
              let mode = LessonMode(rawValue: attempt.skill)
        else { return nil }
        return LessonCoordinate(
            courseId: attempt.courseId,
            lessonId: attempt.lessonId,
            itemId: attempt.itemId,
            mode: mode
        )
    }

    private static func speechIsDegraded(settings: UserSettingsDTO) -> Bool {
        guard let language = try? BCP47Language(settings.targetLanguage) else { return true }
        return !SpeechAvailability.inspect(targetLanguage: language).isOnDeviceReady
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
