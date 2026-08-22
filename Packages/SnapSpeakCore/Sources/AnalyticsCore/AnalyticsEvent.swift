import Foundation
import LanguageKit

/// Analytics events cannot carry raw text, audio, or personal data.
public enum AnalyticsEvent: Sendable, Equatable {
    case lessonStarted(languagePair: String, lessonId: String)
    case lessonCompleted(
        languagePair: String,
        lessonId: String,
        scoreBand: Double?,
        durationBand: String,
        routeCategory: String?
    )
    case downloadFailed(courseId: String)
    // Phase 2 reserved event IDs (not produced in Phase 1): paywall_shown, purchase_succeeded
    case onboardingStarted
    case onboardingCompleted(goalItems: Int, reminderEnabled: Bool, skippedGoal: Bool)
    case onboardingSkipped(step: String)
    case reviewSessionStarted(dueCount: Int, newCount: Int)
    case reviewSessionCompleted(completedCount: Int, durationBand: String)
    case goalMet(goalItems: Int)
    case streakDayRecorded(streakBand: String)
    case streakBroken(lengthBand: String)
    case reminderScheduled(kind: String)
    case reminderOpened(kind: String)
    case driveSessionStarted(dueCount: Int, newCount: Int, lengthCode: String)
    case driveSessionCompleted(
        completedCount: Int,
        durationBand: String,
        endReason: String,
        usedTTSFallback: Bool
    )
    case driveNoteOpened(completedCount: Int)
}
