import AnalyticsCore
import Foundation
import os

/// Phase 1 analytics sink: local os.Logger only. No network, no personal data.
public struct LocalAnalytics: AnalyticsClient {
    private let logger: Logger

    public init(subsystem: String = "app.snapspeak", category: String = "analytics") {
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    public func track(_ event: AnalyticsEvent) {
        switch event {
        case let .lessonStarted(languagePair, lessonId):
            logger.log("lesson_started pair=\(languagePair, privacy: .public) lesson=\(lessonId, privacy: .public)")
        case let .lessonCompleted(languagePair, lessonId, scoreBand, durationBand, routeCategory):
            let band = scoreBand.map { String($0) } ?? "none"
            let route = routeCategory ?? "none"
            logger.log(
                """
                lesson_completed pair=\(languagePair, privacy: .public) \
                lesson=\(lessonId, privacy: .public) band=\(band, privacy: .public) \
                duration=\(durationBand, privacy: .public) route=\(route, privacy: .public)
                """
            )
        case let .downloadFailed(courseId):
            logger.log("download_failed course=\(courseId, privacy: .public)")
        case .onboardingStarted:
            logger.log("onboarding_started")
        case let .onboardingCompleted(goalItems, reminderEnabled, skippedGoal):
            logger.log(
                """
                onboarding_completed goal=\(goalItems, privacy: .public) \
                reminder=\(reminderEnabled, privacy: .public) skipped_goal=\(skippedGoal, privacy: .public)
                """
            )
        case let .onboardingSkipped(step):
            logger.log("onboarding_skipped step=\(step, privacy: .public)")
        case let .reviewSessionStarted(dueCount, newCount):
            logger.log("review_session_started due=\(dueCount, privacy: .public) new=\(newCount, privacy: .public)")
        case let .reviewSessionCompleted(completedCount, durationBand):
            logger.log(
                """
                review_session_completed completed=\(completedCount, privacy: .public) \
                duration=\(durationBand, privacy: .public)
                """
            )
        case let .goalMet(goalItems):
            logger.log("goal_met goal=\(goalItems, privacy: .public)")
        case let .streakDayRecorded(streakBand):
            logger.log("streak_day_recorded band=\(streakBand, privacy: .public)")
        case let .streakBroken(lengthBand):
            logger.log("streak_broken band=\(lengthBand, privacy: .public)")
        case let .reminderScheduled(kind):
            logger.log("reminder_scheduled kind=\(kind, privacy: .public)")
        case let .reminderOpened(kind):
            logger.log("reminder_opened kind=\(kind, privacy: .public)")
        case let .driveSessionStarted(dueCount, newCount, lengthCode):
            logger.log(
                """
                drive_session_started due=\(dueCount, privacy: .public) \
                new=\(newCount, privacy: .public) length=\(lengthCode, privacy: .public)
                """
            )
        case let .driveSessionCompleted(completedCount, durationBand, endReason, usedTTSFallback):
            logger.log(
                """
                drive_session_completed completed=\(completedCount, privacy: .public) \
                duration=\(durationBand, privacy: .public) end=\(endReason, privacy: .public) \
                tts_fallback=\(usedTTSFallback, privacy: .public)
                """
            )
        case let .driveNoteOpened(completedCount):
            logger.log("drive_note_opened completed=\(completedCount, privacy: .public)")
        }
    }
}
